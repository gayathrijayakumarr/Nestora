#include "activity_engine.h"
#include "config.h"

ActivityEngine::ActivityEngine() {
  lastActiveAt_ = millis();
  lastTickSec_ = millis() / 1000;
}

void ActivityEngine::feed(float mag, unsigned long now) {
  float dev = fabsf(mag - 1.0f);
  movement_ = movement_ * 0.9f + dev * 0.1f;

  // --- step detection: threshold crossing + debounce ---
  if (!aboveThresh_ && mag > STEP_THRESHOLD_G &&
      (now - lastStepAt_) > STEP_DEBOUNCE_MS) {
    steps_++;
    lastStepAt_ = now;
    aboveThresh_ = true;
  } else if (aboveThresh_ && mag < 1.0f) {
    aboveThresh_ = false;
  }

  // --- rolling variance window ---
  winBuf_[winIdx_] = mag;
  winIdx_ = (winIdx_ + 1) % 80;
  if (winCount_ < 80) winCount_++;

  // --- fall-candidate state machine (prototype) ---
  if (!spikeSeen_ && mag > FALL_SPIKE_G) {
    spikeSeen_ = true;
    spikeAt_ = now;
    spikeMag_ = mag;
  } else if (spikeSeen_) {
    if (dev < 0.15f && (now - spikeAt_) > 500) {
      // spike followed by quiet -> possible sudden movement
      fallCandidate_ = true;
      spikeSeen_ = false;
    } else if ((now - spikeAt_) > FALL_QUIET_MS) {
      spikeSeen_ = false;  // never went quiet: just activity
    }
  }

  // --- per-second timers + classification ---
  unsigned long sec = now / 1000;
  if (sec != lastTickSec_) {
    lastTickSec_ = sec;
    if (dev > 0.12f) lastActiveAt_ = now;
    unsigned long quietSec = (now - lastActiveAt_) / 1000;
    if (dev < 0.08f) {
      restSec_++;
    } else {
      restSec_ = 0;
    }
    if (quietSec > 60) {
      inactiveSec_ = quietSec;
    } else {
      inactiveSec_ = 0;
    }
    reclassify(now);
  }
}

void ActivityEngine::reclassify(unsigned long now) {
  if (winCount_ < 20) {
    strncpy(activity_, "UNKNOWN", sizeof(activity_));
    return;
  }
  float mean = 0;
  for (int i = 0; i < winCount_; i++) mean += winBuf_[i];
  mean /= winCount_;
  float var = 0;
  for (int i = 0; i < winCount_; i++) {
    float d = winBuf_[i] - mean;
    var += d * d;
  }
  var /= winCount_;

  unsigned long quietSec = (now - lastActiveAt_) / 1000;
  if (quietSec > 300) {
    strncpy(activity_, "VERY_INACTIVE", sizeof(activity_));
  } else if (var > 0.05f || movement_ > 0.35f) {
    strncpy(activity_, "ACTIVE", sizeof(activity_));
  } else if (var > 0.008f || movement_ > 0.12f) {
    strncpy(activity_, "WALKING", sizeof(activity_));
  } else {
    strncpy(activity_, "RESTING", sizeof(activity_));
  }
  activity_[sizeof(activity_) - 1] = '\0';
}
