#pragma once
#include <Arduino.h>
#include <Wire.h>

// MAX30102 driver — resting HR from the optical signal ONLY.
// No MPU linkage: the MPU is strictly steps/activity/safety.
//
// Pipeline (proven LED config: brightness 60, red+IR @100 Hz,
// both amplitudes 0x24, shared bus SDA GPIO12/SCL GPIO13):
//   1. 100-sample blocks at the sensor's 25 Hz rate (4 s) - long enough
//      for a solid autocorrelation, and it matches what the I2C link can
//      drain so the FIFO never overruns
//   2. HR from energy-normalised AUTOCORRELATION over the block.
//      Periodic, not peak-based: an echo inside one beat (dicrotic
//      notch) cannot form a spurious period, which is what doubled the
//      rate with Maxim's 40 ms peak detector. Parabolic sub-sample
//      refinement, gated at corr >= 0.30.
//   3. SpO2 from Maxim (ratio of ratios), validity-gated 70-100
//   4. MEDIAN of last 8 valid blocks + slew limiter: displayed HR moves
//      max 4 BPM per computation because a real heart cannot jump
//      70 -> 150 in one second.
class Max30102Sensor {
 public:
  Max30102Sensor();

  bool begin(TwoWire *bus, uint8_t address);
  void update();  // call as often as possible; one FIFO sample per call

  bool online() const { return online_; }
  bool hasContact() const { return contact_; }
  uint32_t ir() const { return lastIr_; }
  uint32_t red() const { return lastRed_; }

  // Displayed values (-1 when unavailable). currentBpm() is the
  // median + slew-limited value: stable on skin, no spike display.
  int currentBpm() const;
  int averageBpm() const;
  int spo2() const { return spo2_; }
  int minBpm() const { return minBpm_; }
  int maxBpm() const { return maxBpm_; }

  // Prototype 0-100 heuristic (contact + IR strength + steadiness).
  int signalQuality();

  // Telemetry: real optical samples per second (expect ~100) and the
  // hardware FIFO overflow count (must stay 0 for trustworthy timing).
  int sampleRate() const { return sampleRate_; }
  int overflows() const { return fifoOvf_; }

  unsigned long contactThreshold = 10000UL;  // block-average IR

 private:
  void resetBeatState();
  void pushBlock(int bpm);
  int median() const;
  void runMaximBlock();  // HR via autocorrelation, SpO2 via Maxim

  // PROVEN block size (matches the working hardware-test sketch and
  // the Maxim algorithm's design: it always processes its internal
  // BUFFER_SIZE, so the input block must be exactly this long).
  static const int BLOCK_N = 100;  // 1 s @100 Hz, non-overlapping
  uint32_t irBuf_[BLOCK_N] = {0};
  uint32_t redBuf_[BLOCK_N] = {0};
  int bufIdx_ = 0;
  int filled_ = 0;  // real samples collected; compute only when full
  uint64_t blockIrSum_ = 0;
  int blockIrCount_ = 0;

  TwoWire *bus_ = nullptr;
  bool online_ = false;
  bool contact_ = false;
  unsigned long contactLostAt_ = 0;
  uint32_t lastIr_ = 0;
  uint32_t lastRed_ = 0;

  static const int HIST_N = 8;
  int histBuf_[HIST_N] = {0};
  int histCount_ = 0;
  int histIdx_ = 0;

  int displayedBpm_ = -1;  // slew-limited output
  int currentBpm_ = -1;
  int spo2_ = -1;
  int minBpm_ = -1;
  int maxBpm_ = -1;
  float beatConsistency_ = 0.0f;
  int prevBpm_ = -1;
  uint8_t ourRd_ = 0;      // our FIFO read pointer
  int fifoOvf_ = 0;        // hardware overflow counter
  int sampleRate_ = 0;     // samples per second (measured)
  int fifoCount_ = 0;
  unsigned long fifoWinAt_ = 0;
};
