#include "health_engine.h"
#include <string.h>
#include <stdio.h>

// Prototype reference ranges for NESTORA V1 (wellness context ONLY):
//   Resting:        typical adult 60-100; pregnant often 70-110
//                   (pregnancy commonly +10-20 vs pre-pregnancy)
//   Light activity: adult ~80-125; pregnant ~90-130
//   Intense effort: ~120-170 general; pregnancy has NO single fixed
//                   cutoff — ACOG recommends perceived effort /
//                   the talk test, since responses vary.
// These are NOT clinical thresholds and NOT a diagnosis. The device
// measures the mother only.

#define PREG_REST_LO 70
#define PREG_REST_HI 110
#define PREG_LIGHT_LO 90
#define PREG_LIGHT_HI 130
#define VERY_HIGH_HR 160

static bool is_resting(const char *activity) {
  return strcmp(activity, "RESTING") == 0 ||
         strcmp(activity, "VERY_INACTIVE") == 0 ||
         strcmp(activity, "UNKNOWN") == 0;
}

static bool is_light(const char *activity) {
  return strcmp(activity, "WALKING") == 0 ||
         strcmp(activity, "ACTIVE") == 0;
}

void HealthEngine::contextMessage(int hr, const char *activity, bool contact,
                                  char *out, size_t cap) {
  if (!contact || hr < 0) {
    snprintf(out, cap, "Place sensor on skin for heart-rate.");
    return;
  }
  // Very high regardless of activity: rest now, talk-test guidance.
  if (hr >= VERY_HIGH_HR) {
    snprintf(out, cap,
             "HR %d: very high — stop and rest now. Effort is best "
             "judged by the talk test, not one fixed number; seek "
             "care if it stays up.",
             hr);
    return;
  }
  if (is_light(activity)) {
    if (hr >= PREG_LIGHT_LO && hr <= PREG_LIGHT_HI) {
      snprintf(out, cap,
               "HR %d during %s: within the usual light-activity "
               "range (90-130).",
               hr, activity);
    } else if (hr > PREG_LIGHT_HI) {
      snprintf(out, cap,
               "HR %d during %s: above the usual light-activity "
               "range. Slow down and rest.",
               hr, activity);
    } else {
      snprintf(out, cap,
               "HR %d during %s: below the usual light-activity "
               "range. Re-check placement.",
               hr, activity);
    }
    return;
  }
  // Resting (covers UNKNOWN until activity classifies).
  if (hr >= PREG_REST_LO && hr <= PREG_REST_HI) {
    snprintf(out, cap, "HR %d (%s): steady within the usual resting "
                       "range (70-110).",
             hr, activity);
  } else if (hr > PREG_REST_HI) {
    snprintf(out, cap,
             "HR %d while %s: above the usual resting range. Rest "
             "and re-check; contact clinician if persistent.",
             hr, activity);
  } else {
    snprintf(out, cap,
             "HR %d while %s: below the usual resting range. "
             "Re-check sensor placement.",
             hr, activity);
  }
}
