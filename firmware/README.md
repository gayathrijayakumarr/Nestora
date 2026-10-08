# NESTORA V1 Firmware (ESP32-S3 Super Mini)

> # ⚠️ DO NOT MODIFY THIS CODE
>
> **This firmware is finished, tested, and working. Do not edit, optimise,
> refactor or rewrite any file here unless the project owner explicitly asks
> you to.**
>
> The heart-rate pipeline measures a stable **61–66 BPM** with SpO₂ 93–100%.
> Several reasonable-sounding changes made it worse — lowering the sample rate
> caused double-counting (reporting 154 BPM for a ~77 BPM heart), and
> loosening the correlation gates let phantom readings through. There is no
> way to verify a change without flashing real hardware.
>
> Safe to do: `build.sh` (compile), `upload.sh` (flash), and reading the code
> to understand or explain it. Everything else — leave it alone.

Wearable: MAX30102 (HR/PPG) + MPU6050 (accel/gyro).
Flow: `WEARABLE -> BLE -> Flutter gateway -> FastAPI -> Dashboard`.

## Wiring (SHARED I2C bus — proven on hardware)

| ESP32-S3 | MPU6050 | MAX30102/HW-605 |
|----------|---------|-----------------|
| 3V3      | VCC     | VIN             |
| GND      | GND     | GND             |
| GPIO12   | SDA     | SDA             |
| GPIO13   | SCL     | SCL             |

Addresses: MPU6050 `0x68`, MAX30102 `0x57` (both confirmed on hardware).

## Build / upload (no Arduino IDE)

```bash
./build.sh    # compile check, no device needed
./upload.sh   # needs /dev/ttyACM0 (or PORT=/dev/ttyACM1 ./upload.sh)
```

Requires: `arduino-cli`, esp32 core (`esp32:esp32:esp32s3`),
libs: `NimBLE-Arduino`, `SparkFun MAX3010x`, `Adafruit MPU6050`
(+ BusIO / Unified Sensor). Note: `build.sh` passes `-DESP32`
because esp32 core 3.x dropped that macro and Adafruit BusIO needs it.

## BLE

- Name: `Nestora-V1`, NimBLE, MTU requested 247 (JSON never truncated)
- Service `7e570001-…-0001`
- Vitals notify `…-0002`: compact JSON —
  `device_id, timestamp, heart_rate, heart_rate_avg, spo2(null = unavailable), steps, activity, movement, rest_seconds, contact, signal_quality, fall_candidate`
- Status read `…-0003`: `device_id, uptime_s, mpu, max, clients`

No temperature / BP: this hardware cannot measure them, so those
fields are never faked (backend keeps its existing values).

## Notes

- Maternal-only wellness prototype, NOT a diagnostic device.
- Ranges in `health_engine.cpp` are prototype reference ranges,
  not WHO/pregnancy thresholds.
- `fall_candidate` means "possible sudden movement", never "fall confirmed".
- Steps/reset timers restart on reboot (prototype).
- LiPo + aggressive power saving come later; loop uses `millis()`
  scheduling (no long `delay()`), MAX LED current still tunable.
