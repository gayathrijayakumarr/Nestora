#pragma once
#include <Arduino.h>

// ============================================================
// NESTORA V1 — shared data model
// Architecture: WEARABLE -> PHONE(BLE) -> BACKEND(HTTP) -> DASHBOARD
// The phone is the gateway; the dashboard never touches BLE.
// ============================================================

// Maternal-only wellness reading. This device does NOT measure:
// fetal HR, contractions, blood pressure, temperature.
struct WearableReading {
  char device_id[20];
  uint32_t timestamp;      // millis since boot
  int heart_rate;          // -1 = unavailable (no contact / not locked)
  int heart_rate_avg;      // -1 = unavailable
  int spo2;                // -1 = unavailable (not reliably measurable yet)
  uint32_t steps;          // steps since boot (prototype)
  char activity[16];       // RESTING/WALKING/ACTIVE/VERY_INACTIVE/UNKNOWN
  float movement;          // accel magnitude deviation from 1g
  uint32_t rest_seconds;
  bool contact;
  int signal_quality;      // 0-100 prototype heuristic
  bool fall_candidate;     // prototype flag: "possible sudden movement"
};

// Compact JSON, fits comfortably in one BLE notify window at MTU 185+.
// Missing sensors are null — never zero (null != zero).
// Returns bytes written (excl. NUL), 0 on truncation.
inline size_t wearable_to_json(const WearableReading &r, char *out, size_t cap) {
  char hrBuf[12], hrAvgBuf[12], spo2Buf[12];
  if (r.heart_rate < 0) snprintf(hrBuf, sizeof(hrBuf), "null");
  else snprintf(hrBuf, sizeof(hrBuf), "%d", r.heart_rate);
  if (r.heart_rate_avg < 0) snprintf(hrAvgBuf, sizeof(hrAvgBuf), "null");
  else snprintf(hrAvgBuf, sizeof(hrAvgBuf), "%d", r.heart_rate_avg);
  if (r.spo2 < 0) snprintf(spo2Buf, sizeof(spo2Buf), "null");
  else snprintf(spo2Buf, sizeof(spo2Buf), "%d", r.spo2);

  int n = snprintf(out, cap,
    "{\"device_id\":\"%s\",\"timestamp\":%lu,"
    "\"heart_rate\":%s,\"heart_rate_avg\":%s,\"spo2\":%s,"
    "\"steps\":%lu,\"activity\":\"%s\",\"movement\":%.2f,"
    "\"rest_seconds\":%lu,\"contact\":%s,\"signal_quality\":%d,"
    "\"fall_candidate\":%s}",
    r.device_id, (unsigned long)r.timestamp,
    hrBuf, hrAvgBuf, spo2Buf,
    (unsigned long)r.steps, r.activity, r.movement,
    (unsigned long)r.rest_seconds,
    r.contact ? "true" : "false", r.signal_quality,
    r.fall_candidate ? "true" : "false");
  if (n < 0 || (size_t)n >= cap) return 0;
  return (size_t)n;
}
