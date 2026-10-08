#pragma once
#include <Arduino.h>

// BLE peripheral: advertises "Nestora-V1", exposes
// - vitals notify characteristic (compact JSON, models.h)
// - status read characteristic (device/uptime/sensor state)
// NimBLE backend (arduino-esp32 core 3.x). MTU negotiated up so the
// JSON notify is never silently truncated.
class BleService {
 public:
  BleService();

  void begin();
  // Call from loop(); handles slow re-advertising if needed.
  void update();
  // Publish JSON payload to subscribed phone(s). Safe with no clients.
  void notifyVitals(const char *json);
  int clients() const { return clients_; }
  bool advertising();
  bool advStarted() const { return advStarted_; }
  void setStatus(const char *json);

 private:
  int clients_ = 0;
  bool advStarted_ = false;
  char status_[160] = "{}";
  friend class BleConnCallbacks;
};
