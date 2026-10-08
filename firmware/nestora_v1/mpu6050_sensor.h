#pragma once
#include <Arduino.h>
#include <Wire.h>

// MPU6050 wrapper (dedicated bus MPU_BUS, addr 0x68).
// Units: accelerometer in g, gyro in degrees/sec.
class Mpu6050Sensor {
 public:
  Mpu6050Sensor();

  // True when the IMU answers. Never crashes when missing.
  bool begin(TwoWire *bus, uint8_t address);
  // Call every ~25 ms. No-op when offline.
  void update();

  bool online() const { return online_; }
  float ax() const { return ax_; }
  float ay() const { return ay_; }
  float az() const { return az_; }
  float gx() const { return gx_; }
  float gy() const { return gy_; }
  float gz() const { return gz_; }

  // |a| in g, ~1.0 at rest.
  float magnitude() const;

 private:
  bool online_ = false;
  float ax_ = 0, ay_ = 0, az_ = 1.0f;
  float gx_ = 0, gy_ = 0, gz_ = 0;
};
