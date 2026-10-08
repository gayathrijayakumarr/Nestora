# NESTORA — Smart Maternal Healthcare Monitoring System

A full-stack maternal healthcare monitoring system that combines **IoT wearables**, **AI risk prediction**, and **mobile/web dashboards** to give expectant mothers continuous, intelligent care during pregnancy.

Built for a college project. All data is **mock/offline** — no real auth, no real devices, no database. Everything runs locally.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | Python, FastAPI, Uvicorn |
| Mobile App | Flutter (Dart) |
| Doctor Dashboard | React, TypeScript, Vite |
| AI Risk Engine | Python (rule-based scoring) |
| Database | None — mock data in code |

---

## Project Structure

```
iot-nestora/
├── backend/               # FastAPI REST API
│   └── app/
│       ├── main.py        # App entry, router registration
│       ├── routes/        # API endpoints per feature
│       │   ├── vitals.py      # + POST /live ingest
│       │   ├── symptoms.py    # + POST create
│       │   ├── reminders.py   # + POST create, PUT update
│       │   ├── patients.py
│       │   ├── risk.py        # GET /{id}, POST /evaluate, POST /assess
│       │   └── nutrition.py
│       └── services/
│           ├── mock_data.py     # All mock patients/vitals/symptoms
│           ├── risk_engine.py   # Rule-based risk scoring (v2)
│           └── live_store.py    # In-memory live wearable readings
├── firmware/              # ESP32-S3 wearable firmware (real)
│   ├── build.sh / upload.sh
│   └── nestora_v1/         # modular tabs: config, models, sensors,
│                           # activity_engine, health_engine, ble_service
├── mobile/                # Flutter app (Android) — BLE gateway
│   └── lib/
│       ├── main.dart
│       ├── screens/
│       │   ├── landing_screen.dart
│       │   ├── login_screen.dart
│       │   ├── home_screen.dart
│       │   ├── vitals_screen.dart
│       │   ├── symptoms_screen.dart
│       │   ├── reminders_screen.dart
│       │   ├── nutrition_screen.dart
│       │   └── profile_screen.dart
│       └── services/
│           ├── api_service.dart    # HTTP + offline fallback
│           ├── ble_service.dart    # Nestora-V1 BLE gateway
│           └── session_service.dart# Profile/session persistence
├── doctor-dashboard/      # React + TS web dashboard
└── ai/                    # ML models (future; engine is rule-based)
```

---

## Data flow (live wearable path)

```
MAX30102 + MPU6050        (shared I2C: GPIO12 SDA / GPIO13 SCL)
        ▼
ESP32-S3 firmware          BLE "Nestora-V1", compact JSON @1 Hz
        ▼
Flutter app (gateway)      only BLE client; POSTs to backend
        ▼
FastAPI /api/vitals/live   in-memory (120 s TTL)
        ▼
GET /api/vitals/{id}/latest  live merged into mock record
        ▼
Doctor dashboard            LIVE DEVICE badge, live-only patient filter
```

Mock fallback is preserved everywhere: with the wearable off, every
screen keeps working on mock data.

---

## Wearable firmware

Hardware: ESP32-S3 Super Mini + MAX30102/HW-605 (HR/PPG) + MPU6050.
Both sensors share one I2C bus: `SDA=GPIO12`, `SCL=GPIO13`
(MPU `0x68`, MAX `0x57`). The wearable measures the **mother only** —
no fetal HR, BP, temperature or contractions.

```bash
cd firmware
./build.sh    # compile check (no hardware needed)
./upload.sh   # flash; needs the board in download mode
```

The board has no auto-reset circuit: hold **BOOT**, tap **RESET**,
release **BOOT**, then flash. Heart rate uses autocorrelation over
1-second optical blocks (median-of-8 + slew limiter); SpO2 comes from
the Maxim routine and is validity-gated. Prototype reference ranges:
resting 70–110, light activity 90–130.

---

> ⚠️ **Warning:** the `firmware/` folder (ESP32 wearable code) is finished and
> verified. **Do not modify it** unless the project owner asks — see
> [the full warning](docs/WINDOWS_SETUP.md#️-warning--do-not-touch-the-firmware-code).

## Setup guides

- **[Windows setup (complete, step by step)](docs/WINDOWS_SETUP.md)** — recommended
  for new machines and for anyone cloning the repo for the first time.
- [Manual setup](#prerequisites) — platform-agnostic instructions below.

---

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| Python | 3.10+ | Backend |
| Flutter | 3.x | Mobile app |
| Android Studio / SDK | Any recent | Building APK |
| Node.js | 18+ | Doctor dashboard |
| (Optional) ADB + phone | — | Run app on device |

---

## 1. Backend Setup (FastAPI)

```bash
cd backend

# create & activate virtual environment
python -m venv venv
source venv/bin/activate        # Linux/macOS
# venv\Scripts\activate          # Windows

# install dependencies
pip install -r requirements.txt

# run the server
uvicorn app.main:app --reload
```

Verify: open http://localhost:8000 → should show `{"message": "NESTORA API is running"}`
Interactive docs: http://localhost:8000/docs

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/health` | Health check |
| GET | `/api/vitals/{patient_id}` | Vital history (10 readings per patient) |
| GET | `/api/vitals/{patient_id}/latest` | Latest single reading |
| GET | `/api/symptoms/{patient_id}` | Logged symptoms |
| GET | `/api/reminders/{patient_id}` | Reminders |
| GET | `/api/patients` | All patients |
| GET | `/api/patients/{patient_id}` | Single patient |
| GET | `/api/risk/{patient_id}` | Risk assessment (scores live reading when fresh) |
| GET | `/api/nutrition/{patient_id}` | Daily nutrition data |
| POST | `/api/vitals/live` | **Wearable ingest** (gateway POST; alias `/ingest`) |
| POST | `/api/symptoms/` | Create symptom entry |
| POST | `/api/reminders/` | Create reminder |
| PUT | `/api/reminders/{id}` | Toggle reminder completion |
| POST | `/api/risk/assess` | Assess arbitrary vitals + week + symptoms |

Mock patients: `P001` (medium risk), `P002` (low), `P003` (high), `P004` (low), `P005` (medium).

### Risk engine (rule-based, not ML)

Prototype reference ranges — **not clinical thresholds, not a diagnostic
device**: BP ≥140/90 +3, SpO₂ <95 +3, HR >100 +1, temperature ≥38 °C +2,
concerning symptom +2, headache+swelling combo +3, late gestation +1.
Score 0–2 low, 3–5 medium, 6–8 high, 9+ critical. Every response lists
the contributing factors plus a recommendation.

---

## 2. Mobile App Setup (Flutter)

```bash
cd mobile
flutter pub get

# run on connected device / emulator
flutter run

# or build APK (arm64 keeps the size down for physical phones)
flutter build apk --debug --target-platform android-arm64
```

### Connecting the wearable

1. App → tap the avatar → **Profile** → set **Server IP** to your PC's LAN
   address (e.g. `192.168.1.5`) → Save. Emulator uses `10.0.2.2` by default.
2. Home → tap the **Connect band** chip → grant Bluetooth/location
   permission → it scans for `Nestora-V1` and switches to **LIVE**.
3. Wearable connected but no skin contact shows a `—` placeholder rather
   than a stale number. Band switched off → mock fallback resumes.

> **Note:** The app runs fully standalone with hardcoded data. To make it talk to the backend, the backend server must be running on the same machine (or your phone must reach your computer's IP). API base URL is in `mobile/lib/services/api_service.dart`.

### Screens Overview

| Screen | What it shows |
|---|---|
| **Landing** | Animated NESTORA text, auto-navigates to login after 3s |
| **Login** | Styled login with background image, gradient button (no real auth) |
| **Home** | Greeting, pregnancy progress bar, live vital cards, AI risk badge, quick actions |
| **Vitals** | Custom-painted line charts: Heart Rate, SpO2, Temperature + dual-line BP |
| **Symptoms** | Filter chips, symptom cards with severity dots, AI flag badges, log bottom sheet |
| **Reminders** | Toggle-able reminder cards (medication/hydration/appointment/nutrition) |
| **Nutrition** | Calorie circles, nutrient progress bars, water tracker, meal sections |

---

## 3. Doctor Dashboard Setup (React + TypeScript)

```bash
cd doctor-dashboard
npm install
npm run dev
```

Open http://localhost:5173

Features: sidebar navigation, overview page with 4 summary cards, patient table with risk badges, patient detail view with vital cards and trend indicators.

---

## Common Issues

**Gradle build fails / daemon crashes (Flutter)**
```bash
# memory already reduced to 4G in mobile/android/gradle.properties
cd mobile && flutter clean && flutter pub get && flutter build apk --debug
```

**Port 8000 already in use**
```bash
uvicorn app.main:app --reload --port 8001
```

**App shows blank/white screen**
Make sure backend isn't required for the screen you're viewing — all screens have fallback mock data.

---

## Contributors

- **Naveen** — backend, AI risk engine, project architecture
- **Nigesh** — mobile app UI screens
