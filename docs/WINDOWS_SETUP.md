# NESTORA — Windows Setup Guide (Complete)

Follow this top to bottom on a **Windows 10/11** machine. Every command is
written for **PowerShell** (the blue Windows terminal). If you use Command
Prompt, the commands are the same unless noted.

---

> # ⚠️ WARNING — DO NOT TOUCH THE FIRMWARE CODE
>
> **The entire `firmware/` folder is finished, tested, and working.
> Do NOT edit, "improve", optimise, refactor, or rewrite any file inside it
> unless the project owner explicitly asks you to.**
>
> Specifically leave alone:
> - `firmware/nestora_v1/max30102_sensor.cpp` — heart-rate and SpO₂ sensing
> - `firmware/nestora_v1/activity_engine.cpp` — steps and activity
> - `firmware/nestora_v1/health_engine.cpp` — pregnancy HR ranges
> - `firmware/nestora_v1/ble_service.cpp` — Bluetooth broadcasting
> - `firmware/nestora_v1/nestora_v1.ino` — main loop
> - `firmware/config.h`, `firmware/nestora_v1/models.h`
>
> **Why this warning exists:** the heart-rate pipeline took many attempts to
> get right. It now measures a stable **61–66 BPM** with SpO₂ 93–100%. Several
> plausible-looking "improvements" made the result *worse* — dropping the
> sample rate caused double-counting (154 BPM reported for a ~77 BPM heart),
> and loosening the signal gates let phantom readings through. Changing the
> code without hardware to test on will break a working sensor.
>
> **You MAY safely do these firmware things:**
> - `build.sh` / `upload.sh` (compile and flash)
> - Reading the code to understand or explain it
> - The wiring table in section 7
>
> Everything else in this project — backend, mobile app, dashboard — is
> open to change. Only the firmware is off-limits.

---

## 0. What this project is (read this first)

NESTORA is a **Smart Maternal Wellness Monitoring System** — a college
viva prototype. It is **not a medical device** and makes no diagnosis.

Data flows in one direction:

```
MAX30102 (heart rate) + MPU6050 (movement) on a wearable
        │  Bluetooth Low Energy
        ▼
Flutter mobile app  ← the phone is the "gateway"; only the phone talks BLE
        │  HTTP
        ▼
FastAPI backend  ← stores the latest reading in memory
        │
        ▼
React doctor dashboard  ← shows live data to the doctor
```

There are **4 parts** you run separately. Two are servers, one is the phone
app, one is optional hardware.

| Part | Folder | What it does | Needed for demo? |
|---|---|---|---|
| Backend | `backend/` | FastAPI server, mock data, risk engine | **Yes** |
| Doctor dashboard | `doctor-dashboard/` | Web page the doctor views | **Yes** |
| Mobile app | `mobile/` | Flutter app the mother uses | **Yes** |
| Wearable firmware | `firmware/` | Code for the ESP32 sensor band | Only if you have hardware |

Everything works **without the wearable** — the app falls back to demo data.

---

## 1. Install the tools

Install these five. Tick "Add to PATH" wherever the installer offers it.

| Tool | Version | Download |
|---|---|---|
| Git | any recent | https://git-scm.com/download/win |
| Python | **3.11 or 3.12** (3.13/3.14 also fine now) | https://python.org/downloads/windows/ |
| Node.js | **LTS (20 or 22)** | https://nodejs.org/ |
| Flutter | stable (3.29+) | https://docs.flutter.dev/get-started/install/windows |
| Android Studio | latest | https://developer.android.com/studio |

**Android Studio** gives you the Android SDK + emulator the Flutter app needs.

### Verify the installs (close and reopen PowerShell first)

```powershell
git --version
python --version
node --version
npm --version
flutter --version
```

If `flutter` is not found, open a **new** PowerShell window. If it still
fails, Flutter is not on PATH — reinstall and tick the PATH box.

Tell Flutter where Android Studio is:

```powershell
flutter config --android-studio-dir="C:\Program Files\Android\Android Studio"
flutter doctor
```

`flutter doctor` will list problems. Fix anything showing a red ✗ before
continuing — usually "Android toolchain" is the one that matters.

---

## 2. Clone the project

```powershell
cd $HOME
git clone git@github.com:Naveen-Git-12/iot-nestora.git
cd iot-nestora
```

That clones over SSH. If she doesn't have GitHub SSH keys set up, use HTTPS
instead — no key setup needed:

```powershell
git clone https://github.com/Naveen-Git-12/iot-nestora.git
```

---

## 3. Run the backend (FastAPI)

Open PowerShell #1 — **this window stays open for the whole session**.

```powershell
cd $HOME\iot-nestora\backend

# create an isolated environment
python -m venv venv

# activate it (PowerShell)
.\venv\Scripts\Activate.ps1
```

> If PowerShell blocks the activation script as "cannot be loaded", run this
> once in the same window:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

Install and start:

```powershell
pip install --upgrade pip
pip install -r requirements.txt

uvicorn app.main:app --host 0.0.0.0 --port 8000
```

You should see `Uvicorn running on http://0.0.0.0:8000`.

**Verify:** open <http://localhost:8000> in a browser →
`{"message":"NESTORA API is running"}`
Interactive API docs: <http://localhost:8000/docs>

> `--host 0.0.0.0` matters: it lets the **phone** on your Wi-Fi reach the
> server. Don't omit it or the phone will never connect.

---

## 4. Run the doctor dashboard

Open PowerShell #2:

```powershell
cd $HOME\iot-nestora\doctor-dashboard
npm install
npm run dev
```

Open <http://localhost:5173>.

> If another program already uses 5173, Vite will offer the next free port.
> Use whatever URL it prints.

---

## 5. Find your computer's IP address (IMPORTANT)

The phone cannot use `localhost` — it means *the phone itself*. It must
reach your computer by LAN IP.

```powershell
ipconfig
```

Find your **Wi-Fi adapter** (not Bluetooth, not VPN, not Loopback) and read
**IPv4 Address**. It looks like:

```
IPv4 Address. . . . . . . . . . . : 192.168.1.42
```

Write it down. You need it in the next step. If it shows `169.254.x.x`,
you are not connected to Wi-Fi — connect first.

---

## 6. Run the mobile app

### Option A — physical Android phone (recommended, needed for BLE)

1. On the phone: **Settings → About phone →** tap **Build number** 7 times
   → "You are now a developer".
2. **Settings → Developer options → USB debugging** ON.
3. Connect by USB, accept the "Allow USB debugging" popup.
4. Check the phone is seen:
   ```powershell
   adb devices
   ```
   It must show `device`, not `unauthorized`.

Then:

```powershell
cd $HOME\iot-nestora\mobile
flutter pub get
flutter run
```

### Option B — Android emulator (no BLE hardware)

```powershell
flutter emulators          # list available emulators
flutter emulators --launch <emulator-id>
flutter run
```

> The emulator's `10.0.2.2` address already maps to your host, so you can
> **skip the Server IP step** when using an emulator.

### First launch on the phone

The app opens on **Sign In**:

1. Tap **Server settings** (just under the phone number field)
2. Enter your IP from step 5 — e.g. `192.168.1.42` — **no port, no http://**
3. Tap **Sign In** with:
   - Name: `Gayathri`
   - Phone: `9489675377`

The phone and computer must be on the **same Wi-Fi network**. If sign-in
fails, see Troubleshooting below.

> Demo login only — no self-registration. In the real flow a doctor enrols
> the patient from the dashboard first, then the patient signs in. Any
> unknown number is rejected with "User not found".

---

## 7. Optional: the wearable (ESP32-S3)

Only needed if you have the physical sensor band.

**Hardware wiring — both sensors share ONE I2C bus:**

| ESP32-S3 | MPU6050 | MAX30102 |
|---|---|---|
| 3V3 | VCC | VIN |
| GND | GND | GND |
| GPIO12 | SDA | SDA |
| GPIO13 | SCL | SCL |

Addresses: MPU6050 `0x68`, MAX30102 `0x57`.

**Install arduino-cli on Windows:**

```powershell
winget install ArduinoSA.CLI
arduino-cli core update-index
arduino-cli core install esp32:esp32
arduino-cli lib install "NimBLE-Arduino"
arduino-cli lib install "SparkFun MAX3010x Pulse and Proximity Sensor Library"
arduino-cli lib install "Adafruit MPU6050"
arduino-cli lib install "Adafruit BusIO"
arduino-cli lib install "Adafruit Unified Sensor"
```

**Find the serial port** (plug the board in first):

```powershell
Get-CimInstance Win32_SerialPort | Select-Object DeviceID, Name
```

It shows up as `COM3`, `COM5` etc. — note yours.

**Compile-check (no board needed):**

```powershell
cd $HOME\iot-nestora\firmware
.\build.sh
```

If PowerShell won't run the `.sh` scripts, run the compiler directly:

```powershell
cd nestora_v1
arduino-cli compile --fqbn esp32:esp32:esp32s3 `
  --build-property "build.extra_flags=-DARDUINO_USB_CDC_ON_BOOT=1 -DESP32" `
  --output-dir .\build\nestora_v1 .
```

**Flash:**

```powershell
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32s3 --input-dir .\build\nestora_v1
```

> This board has **no auto-reset**, so hold **BOOT**, tap **RESET**, release
> **BOOT**, then run the upload command. Then tap **RESET** once to boot.

**Watch the output:**

```powershell
arduino-cli monitor -p COM3 -c baudrate=115200
```

Healthy output looks like:

```
IR=136563 BPM=61 AVG=61 sr=25/s ovf=0 ... qual=84
```

- `BPM=61` — real heart rate (resting, in the normal 60–100 range)
- `qual` — signal quality; higher is better
- Hold a fingertip over the MAX30102 sensor for 15–20s to get a reading
- `BPM=-1` with low `IR` simply means no finger on the sensor

Press **Ctrl+C** to exit the monitor.

---

## 8. End-to-end verification checklist

Run through this to confirm everything works together.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Backend up | `http://localhost:8000/health` | `{"status":"ok"}` |
| 2 | Dashboard up | `http://localhost:5173` | Patient list appears |
| 3 | Login works | App → Sign In | Lands on Home screen |
| 4 | Unknown user rejected | Sign in as `Nobody / 1111111111` | "User not found…" |
| 5 | Enrol a patient | Dashboard → **Enroll Patient** | New ID appears, can sign in |
| 6 | Mock fallback | App with no wearable | Home shows demo vitals |
| 7 | BP is manual | Tap the BP card → enter `120/80` | Card updates, dashboard shows date |
| 8 | Risk explains itself | Tap **View Risk Details** | List of contributing reasons |
| 9 | Nutrition is personalised | Nutrition tab | "Suggested for Week N" matches her week |
| 10 | Wearable (optional) | Tap **Connect band** | Chip shows **LIVE**, HR appears |
| 11 | Live reaches dashboard | Dashboard → patient detail | **● LIVE DEVICE** badge |

---

## 9. Troubleshooting

**"Could not reach the server" in the app**
The phone can't find your computer.
- Phone and PC on the **same Wi-Fi**?
- Server IP entered correctly (no port, no `http://`)?
- Backend started with `--host 0.0.0.0`?
- Windows Firewall blocking it — run this in **PowerShell as Administrator**:
  ```powershell
  New-NetFirewallRule -DisplayName "NESTORA API" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
  New-NetFirewallRule -DisplayName "NESTORA Dashboard" -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow
  ```
- Restart the app after changing the Server IP.

**Phone shows `unauthorized` in `adb devices`**
Unplug and replug the cable, then accept the "Allow USB debugging" prompt.
Set USB mode to **File Transfer (MTP)** on the phone.

**`flutter doctor` complains about Android licences**
```powershell
flutter doctor --android-licenses
```
Accept all, then re-run `flutter doctor`.

**Port 8000 already in use**
```powershell
netstat -ano | findstr :8000
taskkill /PID <the-number> /F
```

**`adb` not found**
Android Studio installs it at
`%LOCALAPPDATA%\Android\Sdk\platform-tools`. Add that folder to PATH, or use
the full path: `"$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`.

**Wearable not visible in the app**
- Grant Bluetooth **and Location** permission (Android requires location for
  BLE scanning on many versions)
- Hold the phone within ~1 m of the ESP32
- The chip should read **LIVE**; if it says not found, power-cycle the board

**`powershell cannot be loaded` / execution policy error**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## 10. Running it again later

Every session you need to start three things:

```powershell
# Terminal 1 — backend
cd $HOME\iot-nestora\backend
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Terminal 2 — dashboard
cd $HOME\iot-nestora\doctor-dashboard
npm run dev

# Terminal 3 — app on the phone
cd $HOME\iot-nestora\mobile
flutter run
```

Your Server IP is saved on the phone, so you only set it once.

---

## 11. Project layout

```
iot-nestora/
├── backend/                  FastAPI server
│   ├── app/
│   │   ├── main.py           entry point, router registration
│   │   ├── routes/           vitals, symptoms, reminders, patients,
│   │   │                     risk, nutrition, auth
│   │   └── services/         mock_data, risk_engine, patients_store,
│   │                         bp_store, live_store, nutrition_guide
│   └── requirements.txt
├── doctor-dashboard/         React + TypeScript + Vite web app
├── mobile/                   Flutter app
│   └── lib/
│       ├── screens/          landing, login, home, vitals, symptoms,
│       │                     reminders, nutrition, profile
│       └── services/         api_service, ble_service, session_service
├── firmware/                 ESP32-S3 wearable firmware
│   └── nestora_v1/           config.h, models.h, sensor + engine files
├── docs/                     this guide
└── README.md                 project overview
```

---

## 12. Using OpenCode on her machine

Once she has the project running, she can drive it with OpenCode (the same
tool used to build it). Install it, run `opencode` from the project folder,
and paste this:

```
Read README.md and docs/WINDOWS_SETUP.md first.

⚠️ HARD RULE — DO NOT MODIFY THE firmware/ FOLDER.
It is finished and verified (heart rate measures a stable 61-66 BPM,
SpO2 93-100%). Previous "improvements" to it made the readings worse,
including one that reported 154 BPM for a ~77 BPM heart. Do not edit,
optimise, refactor or rewrite anything under firmware/ unless I
explicitly ask you to. You may still read it to explain it, and you
may run firmware/build.sh to compile-check it.

Everything else (backend/, mobile/, doctor-dashboard/) is open to change.

I have the NESTORA project running: backend on port 8000, doctor dashboard
on port 5173, Flutter app installed on a connected Android phone.

Current state:
- Backend: FastAPI, in-memory data, mock patients P001-P005
- Mobile: Flutter, enrolment-gated login, BLE gateway for the Nestora-V1
  wearable, manual BP entry, week-based nutrition, risk details
- Dashboard: React, shows only live-device patients, can enrol patients
- Firmware: ESP32-S3, MAX30102 (HR/SpO2) + MPU6050 (steps/activity) —
  LOCKED, do not modify

The demo login is Gayathri / 9489675377. The app's Server IP setting must
match this machine's LAN IP for the phone to reach the backend.

What would you like to change or add?
```

Useful first requests: "explain how the risk score is calculated",
"add a feature that lets the doctor record a consultation note",
"why does the dashboard only show one patient".