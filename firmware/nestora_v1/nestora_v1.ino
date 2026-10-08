// ============================================================
// NESTORA V1 — ESP32-S3 Super Mini wearable firmware
// Sensors: MAX30102 (HR/PPG, bus 1: GPIO8/9 @0x57)
//          MPU6050 (accel/gyro, bus 0: GPIO12/13 @0x68)
// Flow: WEARABLE -> BLE -> Flutter gateway -> FastAPI -> Dashboard
//
// Build (no Arduino IDE needed):
//   ./build.sh        (compile check, no device required)
//   ./upload.sh       (needs /dev/ttyACM0)
// ============================================================
#include <Arduino.h>
#include <Wire.h>
#include "config.h"
#include "models.h"
#include "max30102_sensor.h"
#include "mpu6050_sensor.h"
#include "activity_engine.h"
#include "health_engine.h"
#include "ble_service.h"

TwoWire SHARED_BUS = TwoWire(0);

static Max30102Sensor maxSensor;
static Mpu6050Sensor mpuSensor;
static ActivityEngine activity;
static BleService ble;

static bool mpuOnline = false;
static bool maxOnline = false;

static unsigned long lastMpu = 0;
static unsigned long lastActivity = 0;
static unsigned long lastHr = 0;
static unsigned long lastBle = 0;
static unsigned long lastDiag = 0;
static unsigned long lastRetry = 0;
static unsigned long fallSetAt = 0;
static unsigned long loopCount_ = 0;
static unsigned long loopWinAt_ = 0;
static int loopRate_ = 0;  // loop() iterations per second (diagnostic)

// Cached at boot: printed in EVERY diag line so the reset cause is
// visible no matter when the serial reader attaches.
static const char *bootReason = "?";

static void i2cScan(TwoWire &bus, const char *label) {
  Serial.printf("[%s] scanning...\n", label);
  for (uint8_t addr = 1; addr < 127; addr++) {
    bus.beginTransmission(addr);
    if (bus.endTransmission() == 0) {
      Serial.printf("[%s] Found 0x%02X\n", label, addr);
    }
  }
}

static const char *resetReasonName() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "POWERON";
    case ESP_RST_BROWNOUT: return "BROWNOUT (power dip!)";
    case ESP_RST_SW: return "SOFTWARE";
    case ESP_RST_PANIC: return "PANIC";
    case ESP_RST_INT_WDT: return "INT_WDT";
    case ESP_RST_TASK_WDT: return "TASK_WDT";
    case ESP_RST_WDT: return "WDT";
    case ESP_RST_DEEPSLEEP: return "DEEPSLEEP";
    case ESP_RST_SDIO: return "SDIO";
    default: return "UNKNOWN";
  }
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0) < 2000) {
    // USB-CDC grace period; never block forever on battery.
  }

  Serial.println();
  Serial.println("================================");
  Serial.println("         NESTORA V1");
  Serial.println("================================");
  Serial.println("MCU: ESP32-S3 Super Mini");
  bootReason = resetReasonName();
  Serial.printf("Reset reason: %s\n", bootReason);
  Serial.println();

  SHARED_BUS.begin(SHARED_SDA, SHARED_SCL);
  SHARED_BUS.setClock(400000);  // proven sketch runs 400 kHz, not default 100 kHz

  Serial.printf("SHARED BUS:\nSDA = GPIO%d\nSCL = GPIO%d\n", SHARED_SDA, SHARED_SCL);
  i2cScan(SHARED_BUS, "SHARED BUS");
  mpuOnline = mpuSensor.begin(&SHARED_BUS, MPU_ADDRESS);
  Serial.println(mpuOnline ? "MPU6050 ONLINE" : "MPU6050 OFFLINE");

  maxOnline = maxSensor.begin(&SHARED_BUS, MAX_ADDRESS);
  Serial.println(maxOnline ? "MAX30102 ONLINE" : "MAX30102 OFFLINE");

  ble.begin();
  Serial.println();
  Serial.println("BLE:");
  Serial.println(BLE_DEVICE_NAME);
  Serial.println("READY");
  Serial.println();
}

void loop() {
  unsigned long now = millis();

  // Loop-rate tracker (proves whether the loop keeps up with the sensor).
  loopCount_++;
  if (loopWinAt_ == 0) loopWinAt_ = now;
  if (now - loopWinAt_ >= 1000) {
    loopRate_ = (int)loopCount_;
    loopCount_ = 0;
    loopWinAt_ = now;
  }

  // MAX30102: drain the whole FIFO backlog every loop (up to 32).
  // A fixed small drain lets the 32-deep hardware FIFO overflow
  // between loops; overflowed gaps make peak intervals meaningless
  // and block HR swings wildly (107/136/214/187 on one touch).
  maxSensor.update();  // drains everything available internally
  loopCount_++;

  // Retry offline sensors every 30 s (lets user reseat wires live).
  if (now - lastRetry >= 30000) {
    lastRetry = now;
    if (!mpuOnline) {
      mpuOnline = mpuSensor.begin(&SHARED_BUS, MPU_ADDRESS);
      if (mpuOnline) Serial.println("MPU6050 ONLINE (retry)");
    }
    if (!maxOnline) {
      maxOnline = maxSensor.begin(&SHARED_BUS, MAX_ADDRESS);
      if (maxOnline) Serial.println("MAX30102 ONLINE (retry)");
    }
  }

  // Auto-clear a latched fall candidate after 60 s (fresh events re-latch).
  if (activity.fallCandidate()) {
    if (fallSetAt == 0) {
      fallSetAt = now;
    } else if (now - fallSetAt > 60000) {
      activity.clearFallCandidate();
      fallSetAt = 0;
    }
  } else {
    fallSetAt = 0;
  }

  // MPU6050 @ ~40 Hz
  if (now - lastMpu >= MPU_SAMPLE_MS) {
    lastMpu = now;
    mpuSensor.update();
    activity.feed(mpuSensor.magnitude(), now);
  }

  // Activity context log @ 2 Hz (serial only)
  if (now - lastActivity >= ACTIVITY_UPDATE_MS) {
    lastActivity = now;
  }

  // HR snapshot @ 1 Hz (serial only)
  if (now - lastHr >= HEART_RATE_UPDATE_MS) {
    lastHr = now;
  }

  // BLE notify @ 1 Hz
  if (now - lastBle >= BLE_NOTIFY_MS) {
    lastBle = now;

    WearableReading r;
    strncpy(r.device_id, DEVICE_ID, sizeof(r.device_id));
    r.timestamp = now;
    r.heart_rate = maxOnline ? maxSensor.currentBpm() : -1;
    r.heart_rate_avg = maxOnline ? maxSensor.averageBpm() : -1;
    r.spo2 = maxOnline ? maxSensor.spo2() : -1;  // Maxim-validated or null
    r.steps = activity.steps();
    strncpy(r.activity, activity.activity(), sizeof(r.activity));
    r.activity[sizeof(r.activity) - 1] = '\0';
    r.movement = activity.movement();
    r.rest_seconds = activity.restSeconds();
    r.contact = maxOnline ? maxSensor.hasContact() : false;
    r.signal_quality = maxOnline ? maxSensor.signalQuality() : 0;
    r.fall_candidate = activity.fallCandidate();

    char payload[256];
    if (wearable_to_json(r, payload, sizeof(payload)) > 0) {
      ble.notifyVitals(payload);
    }

    char status[160];
    snprintf(status, sizeof(status),
             "{\"device_id\":\"%s\",\"uptime_s\":%lu,"
             "\"mpu\":%s,\"max\":%s,\"clients\":%d}",
             DEVICE_ID, now / 1000,
             mpuOnline ? "true" : "false",
             maxOnline ? "true" : "false",
             ble.clients());
    ble.setStatus(status);
  }

  // Periodic serial diagnostics @ 5 s
  if (now - lastDiag >= DIAG_PRINT_MS) {
    lastDiag = now;
    char ctx[160];
    HealthEngine::contextMessage(
        maxSensor.currentBpm(), activity.activity(),
        maxSensor.hasContact(), ctx, sizeof(ctx));
    Serial.printf(
        "IR=%lu RED=%lu BPM=%d AVG=%d sr=%d ovf=%d | mag=%.2f steps=%lu act=%s rest=%lus "
        "qual=%d fall=%d ble_adv=%d started=%d clients=%d heap=%lu rst=%s | %s\n",
        (unsigned long)maxSensor.ir(), (unsigned long)maxSensor.red(),
        maxSensor.currentBpm(),
        maxSensor.averageBpm(), maxSensor.sampleRate(),
        maxSensor.overflows(), mpuSensor.magnitude(), activity.steps(),
        activity.activity(), (unsigned long)activity.restSeconds(),
        maxSensor.signalQuality(),
        activity.fallCandidate() ? 1 : 0,
        ble.advertising() ? 1 : 0, ble.advStarted() ? 1 : 0,
        ble.clients(),
        (unsigned long)ESP.getFreeHeap(), bootReason, ctx);
  }

  ble.update();
}
