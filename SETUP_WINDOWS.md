# NESTORA — Windows Setup Guide

Tested on Windows 11 Pro with OPPO Reno7 5G (CPH2371, Android 13).
Repo: https://github.com/Naveen-Git-12/iot-nestora.git

## 0. Install tools (once)

| Tool | Version | Notes |
|---|---|---|
| Git | any recent | `git --version` |
| Python | 3.10+ | tick **Add to PATH** |
| Node.js | 18+ LTS | includes `npm` |
| Flutter | 3.x stable | e.g. `D:\flutter` (see disk note) |
| JDK | 17 | e.g. `D:\jdk-17.0.12+7`, set `JAVA_HOME` |
| Android SDK | 36.x | `C:\Users\<you>\AppData\Local\Android\Sdk` |
| ADB | via `winget install --id Google.PlatformTools` | verify `adb devices -l` |

```powershell
python --version; node --version; npm --version
flutter --version; java -version; adb version
flutter doctor   # repeat until "No issues found!"
```

### flutter doctor fixes we hit

1. **cmdline-tools missing** — download
   `https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip`
   (BITS is more reliable than `Invoke-WebRequest` for big files):
   ```powershell
   Start-BitsTransfer -Source "<url>" -Destination "D:\src\cmdtools.zip"
   Expand-Archive D:\src\cmdtools.zip D:\src\cmdtools-tmp
   Copy-Item D:\src\cmdtools-tmp\cmdline-tools\* `
     C:\Users\<you>\AppData\Local\Android\Sdk\cmdline-tools\latest\ -Recurse -Force
   ```
2. **Licenses** — `flutter doctor --android-licenses` (answer `y`).
3. **NDK 28.2.13676358 download fails / C: full** — NDK is ~3.5 GB
   extracted. If C: is tight, extract to `D:\Android\Sdk\ndk\28.2.13676358`
   and link it (junction needs no admin, symlink does):
   ```powershell
   New-Item -ItemType Junction `
     -Path "$env:LOCALAPPDATA\Android\Sdk\ndk\28.2.13676358" `
     -Target "D:\Android\Sdk\ndk\28.2.13676358"
   ```
4. **Plugin symlinks** — enable Developer Mode
   (Settings → Developers) or:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentControlSet\Control\Session Manager\Environment" -Name "AllowDevelopmentWithoutDevLicense" -Value 1
   ```

> Disk tip: Flutter + Android SDK + Gradle need ~8–10 GB free.
> We installed Flutter/JDK/NDK on `D:` (C: had only ~2.6 GB free).

## 1. Clone

```powershell
git clone https://github.com/Naveen-Git-12/iot-nestora.git
cd iot-nestora
```

## 2. Backend (terminal 1)

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verify: `http://localhost:8000/docs`, `GET /api/patients` → P001–P005.

## 3. Doctor dashboard (terminal 2)

```powershell
cd doctor-dashboard
npm install
npm run dev -- --host 0.0.0.0 --port 5173
```

Open `http://localhost:5173/`. For phone use `http://<PC-WiFi-IP>:5173/`.

## 4. Mobile app (terminal 3)

```powershell
cd mobile
flutter pub get
flutter build apk --debug --target-platform android-arm64
adb devices -l   # OPPO must show as "device" (USB debugging ON)
adb -s <DEVICE-ID> install -r build\app\outputs\flutter-apk\app-debug.apk
```

Signature clash with a friend's build?
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` → uninstall first (wipes app data):
```powershell
adb -s <DEVICE-ID> uninstall com.nestora.nestora_mobile
```

### CRITICAL manifest fix (already applied here — commit it!)

`mobile/android/app/src/main/AndroidManifest.xml` shipped with **no**
`INTERNET` permission and no cleartext allowance, so on Android 9+
every `http://` call fails and login always says
`Could not reach the server`. Required:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<application ... android:usesCleartextTraffic="true">
```

### Launcher icon

Source: `mobile/assets/nestora_icon.png` (1024×1024, icon-only crop —
banners with text don't read at icon size). Regenerate with:

```powershell
dart run flutter_launcher_icons   # config in mobile/pubspec.yaml
```

then rebuild + reinstall.

## 5. Server IP (the step people miss)

1. `ipconfig` → Wi-Fi adapter → IPv4 (e.g. `192.168.29.43`).
2. Phone + PC on the **same Wi-Fi**.
3. In app: Sign In → **Server settings** → type **just the IP**
   (`192.168.29.43` — no `http://`, no `:8000`, no spaces) → Sign In.
4. If Wi-Fi isolation blocks phone→PC (we saw 100% ping loss to the PC
   while the gateway pinged fine), use USB instead:
   ```powershell
   adb -s <DEVICE-ID> reverse tcp:8000 tcp:8000
   ```
   then Server IP = `127.0.0.1` (keep USB plugged in).
5. Firewall (run as Administrator if prompted): allow `python` + `node`
   inbound on Private network.

## 6. Login (enrolment-gated, no signup)

Only these 5 doctor-registered patients work (first name suffices,
last 10 digits of phone):

| Name | Phone |
|---|---|
| Gayathri | 9489675377 |
| Anitha Kumari | 9876543211 |
| Lakshmi Devi | 9876543212 |
| Meena Rajan | 9876543213 |
| Divya Nair | 9876543214 |

Error meanings: `User not found` = number not enrolled;
`Name does not match` = first name ≠ that number;
`Could not reach the server` = network/manif­est issue (§4–5).

## 7. Firmware (later)

Needs ESP32-S3 board + Arduino CLI + `esp32:esp32:esp32s3` core +
libs (`NimBLE-Arduino`, `SparkFun MAX3010x`, `Adafruit MPU6050`).
`firmware/build.sh` is a compile check; `upload.sh` targets
`/dev/ttyACM0` (Linux) — on Windows use `PORT=COMx`.

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `flutter doctor` Android license unknown | `flutter doctor --android-licenses` |
| Gradle `sdkmanager --install ndk` fails / C: full | NDK→D: + junction (§0.3) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | `adb uninstall com.nestora.nestora_mobile`, reinstall |
| Login `Could not reach the server` | manifest fix (§4) + Server IP bare + same Wi-Fi or `adb reverse` (§5) |
| iPhone install from Windows | impossible — needs macOS + Xcode; use Android or TestFlight via Mac/CI |
