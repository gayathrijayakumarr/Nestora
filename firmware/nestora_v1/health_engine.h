#pragma once
#include <Arduino.h>

// Maternal wellness context (NOT a diagnosis).
// Combines HR + activity into a human-readable, viva-safe message.
class HealthEngine {
 public:
  // WTO ("write the observation"): fills out (cap bytes) with one of:
  // - activity-related HR elevation
  // - heart rate elevated compared with resting state
  // - steady / no-contact variants
  static void contextMessage(int hr, const char *activity, bool contact,
                             char *out, size_t cap);
};
