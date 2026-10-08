#include "mpu6050_sensor.h"
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

static Adafruit_MPU6050 mpu;

Mpu6050Sensor::Mpu6050Sensor() {}

bool Mpu6050Sensor::begin(TwoWire *bus, uint8_t address) {
  if (!mpu.begin(address, bus)) {
    online_ = false;
    return false;
  }
  mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  online_ = true;
  return true;
}

void Mpu6050Sensor::update() {
  if (!online_) return;
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);
  ax_ = a.acceleration.x / 9.80665f;
  ay_ = a.acceleration.y / 9.80665f;
  az_ = a.acceleration.z / 9.80665f;
  gx_ = g.gyro.x * 57.29578f;
  gy_ = g.gyro.y * 57.29578f;
  gz_ = g.gyro.z * 57.29578f;
}

float Mpu6050Sensor::magnitude() const {
  return sqrtf(ax_ * ax_ + ay_ * ay_ + az_ * az_);
}
