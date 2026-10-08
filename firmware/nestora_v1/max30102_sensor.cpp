#include "max30102_sensor.h"
#include "config.h"
#include <MAX30105.h>
#include "spo2_algorithm.h"

// ── HR estimation ───────────────────────────────────────────────────────────
// Why not the stock Maxim heart rate: its peak detector allows only 4
// samples (40 ms) between accepted peaks, so the dicrotic notch (which
// lands ~200-300 ms after the main systolic peak) is counted as a second
// beat. That doubles the reported rate - which is exactly what we saw
// (stable 150 at rest => real ~75).
//
// Autocorrelation over the whole block measures PERIODICITY, not
// individual peaks, so an echo inside one beat cannot create a spurious
// period: the only strong periodicity in a 1 s window is the true beat.
#define FS_HZ 100
#define HR_MIN 40
#define HR_MAX 200
// period bounds in samples: 6000/200=30 .. 6000/40=150
#define LAG_MIN 30
#define LAG_MAX 150
// A believable periodicity must correlate this well. 0.30 was far too
// loose: noisy/transition blocks scored just above it and produced
// nonsense rates like 199 BPM.
#define AC_MIN_PEAK 0.35f
// Ceiling for the estimator. Pregnancy effort tops out around 160-170;
// anything above this is optical artifact (dicrotic echo, contact
// transient, motion), not a heart rate.
#define AC_MAX_BPM 180

static MAX30105 particleSensor;

Max30102Sensor::Max30102Sensor() {}

// ── Direct FIFO read ───────────────────────────────────────────────────────
// The SparkFun accessor getRed() calls safeCheck(), which BLOCKS in a
// delay(1) loop (and can return a bogus 0), capping the stream at ~10
// samples/s. We read the FIFO ourselves instead.
//
// Register map verified against the MAX30102 datasheet (and the vendor
// driver): FIFO_DATA is 0x07 - NOT 0x04. Reading 0x04 returns the write
// pointer, which silently produced garbage samples and a stalled stream.
#define REG_FIFO_WR_PTR 0x04
#define REG_FIFO_OVF    0x05   // overflow counter in bits [1:0]
#define REG_FIFO_RD_PTR 0x06
#define REG_FIFO_DATA   0x07
#define BYTES_PER_SAMPLE 6      // 2 LEDs x 3 bytes
#define WIRE_CHUNK 30           // 5 samples; 32 % 6 != 0, so stay under

static uint8_t maxRegRead(TwoWire *bus, uint8_t reg) {
  bus->beginTransmission(MAX_ADDRESS);
  bus->write(reg);
  if (bus->endTransmission() != 0) return 0;
  if (bus->requestFrom(MAX_ADDRESS, (uint8_t)1) != 1) return 0;
  return (uint8_t)bus->read();
}

static void maxRegWrite(TwoWire *bus, uint8_t reg, uint8_t val) {
  bus->beginTransmission(MAX_ADDRESS);
  bus->write(reg);
  bus->write(val);
  bus->endTransmission();
}

bool Max30102Sensor::begin(TwoWire *bus, uint8_t address) {
  bus_ = bus;
  bus_->beginTransmission(address);
  if (bus_->endTransmission() != 0) {
    online_ = false;
    return false;
  }
  if (!particleSensor.begin(*bus_, I2C_SPEED_FAST)) {
    online_ = false;
    return false;
  }
  // Full proven LED config. (A trimmed-current experiment weakened the
  // AC wave; every boot reported rst=POWERON, so brownout was not a
  // factor.)
  particleSensor.setup(
      60,   // LED brightness
      4,    // sampleAverage
      2,    // ledMode: red + IR
      100,  // sampleRate Hz
      411,  // pulseWidth us
      4096  // adcRange
  );
  particleSensor.setPulseAmplitudeRed(0x24);
  particleSensor.setPulseAmplitudeIR(0x24);
  particleSensor.setPulseAmplitudeGreen(0);
  online_ = true;
  ourRd_ = 0;
  fifoOvf_ = 0;
  // Clear any latched overflow counter and resync with the write pointer.
  maxRegWrite(bus_, REG_FIFO_OVF, (uint8_t)~0x03);
  ourRd_ = (uint8_t)(maxRegRead(bus_, REG_FIFO_WR_PTR) & 0x1F);
  resetBeatState();
  return true;
}

void Max30102Sensor::resetBeatState() {
  currentBpm_ = -1;
  displayedBpm_ = -1;
  spo2_ = -1;
  histCount_ = 0;
  histIdx_ = 0;
  bufIdx_ = 0;
  filled_ = 0;
  blockIrSum_ = 0;
  blockIrCount_ = 0;
  fifoCount_ = 0;
  fifoWinAt_ = 0;
  minBpm_ = -1;
  maxBpm_ = -1;
  beatConsistency_ = 0.0f;
  prevBpm_ = -1;
  for (int i = 0; i < HIST_N; i++) histBuf_[i] = 0;
}

void Max30102Sensor::update() {
  if (!online_) return;
  unsigned long now = millis();

  uint8_t wr = (uint8_t)(maxRegRead(bus_, REG_FIFO_WR_PTR) & 0x1F);
  uint8_t ovf = (uint8_t)(maxRegRead(bus_, REG_FIFO_OVF) & 0x03);
  uint8_t avail = (uint8_t)((wr - ourRd_) & 0x1F);

  if (ovf > 0) {
    // Samples were dropped, so the buffered timeline has a gap and peak
    // timing would be meaningless. Flush and restart the blocks.
    ourRd_ = wr;
    fifoOvf_++;
    maxRegWrite(bus_, REG_FIFO_OVF, (uint8_t)~0x03);
    resetBeatState();
    return;
  }
  if (avail == 0) return;

  uint8_t chunk[WIRE_CHUNK];
  while (avail > 0) {
    uint8_t wantSamples =
        (avail > (WIRE_CHUNK / BYTES_PER_SAMPLE))
            ? (uint8_t)(WIRE_CHUNK / BYTES_PER_SAMPLE)
            : avail;
    uint8_t want = (uint8_t)(wantSamples * BYTES_PER_SAMPLE);

    bus_->beginTransmission(MAX_ADDRESS);
    bus_->write(REG_FIFO_DATA);
    bus_->endTransmission();
    uint8_t got = (uint8_t)bus_->requestFrom(MAX_ADDRESS, want);

    uint8_t gotSamples = (uint8_t)(got / BYTES_PER_SAMPLE);
    if (gotSamples == 0) return;  // bus hiccup: retry on the next pass
    for (uint8_t b = 0; b < got; b++) chunk[b] = (uint8_t)bus_->read();

    for (uint8_t k = 0; k < gotSamples; k++) {
      const uint8_t *p = &chunk[k * BYTES_PER_SAMPLE];
      // 3 bytes per LED, MSB first; mask to the 18-bit sample.
      uint32_t red = (((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) |
                      (uint32_t)p[2]) & 0x3FFFFUL;
      uint32_t ir = (((uint32_t)p[3] << 16) | ((uint32_t)p[4] << 8) |
                     (uint32_t)p[5]) & 0x3FFFFUL;

      lastRed_ = red;
      lastIr_ = ir;
      irBuf_[bufIdx_] = ir;
      redBuf_[bufIdx_] = red;
      bufIdx_++;
      if (filled_ < BLOCK_N) filled_++;
      blockIrSum_ += ir;
      blockIrCount_++;

      if (fifoWinAt_ == 0) fifoWinAt_ = now;
      fifoCount_++;
      if (now - fifoWinAt_ >= 1000) {
        sampleRate_ = fifoCount_;
        fifoCount_ = 0;
        fifoWinAt_ = now;
      }

      if (bufIdx_ >= BLOCK_N && filled_ >= BLOCK_N) {
        bufIdx_ = 0;
        runMaximBlock();
      }
    }

    // We consumed `gotSamples` samples; the chip's read pointer advanced
    // with them, so track ours in lockstep.
    ourRd_ = (uint8_t)((ourRd_ + gotSamples) & 0x1F);
    avail = (uint8_t)(avail - gotSamples);
  }
}

// Autocorrelation HR. Returns BPM, or -1 when no periodicity stands out.
// n must be exactly Max30102Sensor::BLOCK_N (1 s @100 Hz).
static int estimateBpmAutocorr(const uint32_t *samples, int n) {
  static float x[100];
  const int NN = n > 100 ? 100 : n;
  float mean = 0;
  for (int i = 0; i < NN; i++) mean += (float)samples[i];
  mean /= NN;
  for (int i = 0; i < NN; i++) x[i] = (float)samples[i] - mean;

  // energy-normalised autocorrelation for each candidate lag
  float best = 0;
  int bestLag = 0;
  for (int lag = LAG_MIN; lag <= LAG_MAX && lag < NN; lag++) {
    float num = 0, d1 = 0, d2 = 0;
    for (int i = 0; i + lag < NN; i++) {
      num += x[i] * x[i + lag];
      d1 += x[i] * x[i];
      d2 += x[i + lag] * x[i + lag];
    }
    float den = sqrtf(d1 * d2);
    if (den <= 0) continue;
    float r = num / den;
    if (r > best) {
      best = r;
      bestLag = lag;
    }
  }
  if (bestLag == 0 || best < AC_MIN_PEAK) return -1;

  // Parabolic refinement around the correlation peak for sub-sample lag.
  float prev = 0, cur = 0, next = 0;
  {
    auto corrAt = [&](int lag) -> float {
      if (lag < LAG_MIN || lag > LAG_MAX || lag >= n) return 0;
      float num = 0, d1 = 0, d2 = 0;
      for (int i = 0; i + lag < NN; i++) {
        num += x[i] * x[i + lag];
        d1 += x[i] * x[i];
        d2 += x[i + lag] * x[i + lag];
      }
      float den = sqrtf(d1 * d2);
      return den > 0 ? num / den : 0;
    };
    cur = corrAt(bestLag);
    prev = corrAt(bestLag - 1);
    next = corrAt(bestLag + 1);
  }
  float shift = 0.0f;
  float denom = (prev - 2 * cur + next);
  if (fabsf(denom) > 1e-9f) shift = 0.5f * (prev - next) / denom;
  float lagEst = bestLag + shift;
  if (lagEst <= 0) return -1;

  float bpm = (FS_HZ * 60.0f) / lagEst;
  if (bpm < HR_MIN || bpm > AC_MAX_BPM) return -1;
  return (int)(bpm + 0.5f);
}

void Max30102Sensor::runMaximBlock() {
  uint32_t avgIr =
      blockIrCount_ > 0 ? (uint32_t)(blockIrSum_ / blockIrCount_) : 0;
  blockIrSum_ = 0;
  blockIrCount_ = 0;
  unsigned long now = millis();

  if (avgIr < contactThreshold) {
    contact_ = false;
    if (contactLostAt_ == 0) contactLostAt_ = now;
    if (now - contactLostAt_ > CONTACT_LOSS_RESET_MS) resetBeatState();
    return;
  }
  if (!contact_) resetBeatState();
  contact_ = true;
  contactLostAt_ = 0;

  int bpm = estimateBpmAutocorr(irBuf_, BLOCK_N);
  // Outlier gate: reject a block that disagrees wildly with the recent
  // median. A single 199 BPM block must never enter the history that
  // drives the displayed value.
  if (bpm > 0 && histCount_ >= 3) {
    int med0 = median();
    if (med0 > 0 && fabsf((float)bpm - (float)med0) / (float)med0 > 0.25f) {
      bpm = -1;
    }
  }
  if (bpm > 0) {
    if (prevBpm_ > 0) {
      float diff = fabsf((float)bpm - (float)prevBpm_) / (float)prevBpm_;
      float sample = 1.0f - fminf(diff * 2.0f, 1.0f);
      beatConsistency_ = beatConsistency_ * 0.7f + sample * 0.3f;
    }
    prevBpm_ = bpm;
    currentBpm_ = bpm;
    if (minBpm_ < 0 || bpm < minBpm_) minBpm_ = bpm;
    if (maxBpm_ < 0 || bpm > maxBpm_) maxBpm_ = bpm;
    pushBlock(bpm);
  }

  // SpO2 still from Maxim, validity-gated (real value or unavailable).
  int32_t spo2 = 0, hrMax = 0;
  int8_t validSpo2 = 0, validHrMax = 0;
  maxim_heart_rate_and_oxygen_saturation(
      irBuf_, BLOCK_N, redBuf_, &spo2, &validSpo2, &hrMax, &validHrMax);
  Serial.printf("SPO2 valid=%d val=%ld | HR_AC=%d\n",
                (int)validSpo2, (long)spo2, bpm);
  if (validSpo2 && spo2 >= 70 && spo2 <= 100) spo2_ = spo2;
  else spo2_ = -1;

  int med = median();
  if (med > 0) {
    if (displayedBpm_ < 0) {
      displayedBpm_ = med;
    } else if (med > displayedBpm_) {
      int d = med - displayedBpm_;
      displayedBpm_ += (d > 4) ? 4 : d;
    } else if (med < displayedBpm_) {
      int d = displayedBpm_ - med;
      displayedBpm_ -= (d > 4) ? 4 : d;
    }
  }
}

void Max30102Sensor::pushBlock(int bpm) {
  histBuf_[histIdx_] = bpm;
  histIdx_ = (histIdx_ + 1) % HIST_N;
  if (histCount_ < HIST_N) histCount_++;
}

int Max30102Sensor::median() const {
  if (histCount_ == 0) return -1;
  int tmp[HIST_N];
  for (int i = 0; i < histCount_; i++) tmp[i] = histBuf_[i];
  for (int i = 1; i < histCount_; i++) {
    int key = tmp[i], j = i - 1;
    while (j >= 0 && tmp[j] > key) {
      tmp[j + 1] = tmp[j];
      j--;
    }
    tmp[j + 1] = key;
  }
  return tmp[histCount_ / 2];
}

int Max30102Sensor::currentBpm() const {
  if (!contact_ || displayedBpm_ < 0) return -1;
  return displayedBpm_;
}

int Max30102Sensor::averageBpm() const {
  int med = median();
  if (!contact_ || med < 0) return -1;
  return med;
}

int Max30102Sensor::signalQuality() {
  if (!online_) return 0;
  if (!contact_) return 0;
  int q = 40;
  float irScore = fminf((float)lastIr_ / 150000.0f, 1.0f) * 30.0f;
  q += (int)irScore;
  q += (int)(beatConsistency_ * 30.0f);
  if (q > 100) q = 100;
  return q;
}