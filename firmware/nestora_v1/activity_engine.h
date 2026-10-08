#pragma once
#include <Arduino.h>

// Prototype activity engine (wellness context only — NOT medical).
// Inputs: accel magnitude @~40Hz. Outputs: step count, activity class,
// rest/inactivity timers, and a "possible sudden movement" candidate flag.
class ActivityEngine {
 public:
  ActivityEngine();

  // Call with each fresh magnitude sample.
  void feed(float magnitude_g, unsigned long now_ms);

  uint32_t steps() const { return steps_; }
  // RESTING / WALKING / ACTIVE / VERY_INACTIVE / UNKNOWN
  const char *activity() const { return activity_; }
  float movement() const { return movement_; }  // | |a|-1g |, smoothed
  uint32_t restSeconds() const { return restSec_; }
  uint32_t inactiveSeconds() const { return inactiveSec_; }
  bool fallCandidate() const { return fallCandidate_; }
  void clearFallCandidate() { fallCandidate_ = false; }

 private:
  void reclassify(unsigned long now_ms);

  uint32_t steps_ = 0;
  unsigned long lastStepAt_ = 0;
  bool aboveThresh_ = false;

  float movement_ = 0.0f;
  float winBuf_[80] = {0.0f};  // 2 s window @40 Hz
  int winIdx_ = 0;
  int winCount_ = 0;

  char activity_[16] = "UNKNOWN";
  uint32_t restSec_ = 0;
  uint32_t inactiveSec_ = 0;
  unsigned long lastActiveAt_ = 0;
  unsigned long lastTickSec_ = 0;

  // fall-candidate state machine
  bool fallCandidate_ = false;
  bool spikeSeen_ = false;
  unsigned long spikeAt_ = 0;
  float spikeMag_ = 0.0f;
};
