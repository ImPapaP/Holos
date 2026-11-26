# Holos

**A Universal Sensory Substitution Mobile Application for Persons with Sensory Disabilities Using Computer Vision, Sound Classification, IoT Sensors, and Haptic Feedback**

Holos turns information from a sense the user has lost into a sense they still have. It detects obstacles, sounds, gas leaks and heat, then alerts the user through voice, full-screen visual alerts or vibration, depending on their profile.

## Profiles

| Profile | Alerts through | Recommended modules |
|---|---|---|
| Blind / low vision | Voice + vibration | Sight, SOS |
| Deaf / hard of hearing | Screen alerts + vibration | Sound, SOS |
| Deafblind | Vibration only | Sight, Sound, Touch Talk, SOS |
| Sensory sensitive (autism, ADHD, anxiety) | Gentle screen alerts + vibration | Calm, SOS |
| Lost smell or touch | Voice + screen + vibration | Sensor Alerts, SOS |

## Modules

- **Sight**: camera + Google ML Kit object detection (on-device). Direction (left/ahead/right) and distance (from box size) become vibration patterns; closer = faster. Tap = pause, double-tap = repeat, hold 1.5 s = SOS.
- **Sound**: microphone level monitoring for sudden and continuous loud sounds (alarms, sirens), plus live captions (speech-to-text, English/Filipino).
- **Touch Talk**: a family member types a message; it is vibrated in Morse code letter by letter.
- **Calm**: noise monitor that warns before overload, plus a haptic breathing guide (4 s in, 4 s hold, 6 s out).
- **Sensor Alerts**: connects to the Holos ESP32 sensor (MQ-2 gas/smoke + LM35 temperature) over Bluetooth LE. Test buttons work without hardware.
- **SOS**: vibrates SOS, gets GPS location, and opens an SMS to the caregiver with a Google Maps link, or calls them. Fall detection (optional) starts SOS with a 10-second countdown.
- **Practice**: learn every vibration pattern.

## Project structure

```
lib/
  main.dart                 App entry, routing by profile
  core/                     State, profiles, strings (EN/FIL), haptics + Morse, output routing, theme
  screens/                  Onboarding, home, settings, practice
  modules/                  Sight, Sound, Touch Talk, Calm, Sensor, SOS
  services/                 Sound watcher, fall detector, BLE sensor
  widgets/                  Shared big-tile buttons
esp32/holos_sensor/         Arduino sketch for the ESP32 sensor
android_setup/              Android permissions to paste into the manifest
```

## How to build (Android)

Requirements: Flutter 3.24 or newer, Android Studio, an Android phone (Android 7+) with USB debugging on.

1. Create the Android/iOS shell, then copy this repo's files over it:
   ```bash
   flutter create --org ph.edu.bulsu --project-name holos holos
   ```
   Copy `lib/`, `pubspec.yaml`, `esp32/`, `android_setup/` and this README into the new `holos/` folder (replace `lib/` and `pubspec.yaml`).
   *If this repo already contains the `android/` folder, skip this step.*
2. Open `android/app/src/main/AndroidManifest.xml` and paste the lines from `android_setup/AndroidManifest_permissions.xml` above the `<application>` tag.
3. Open `android/app/build.gradle` (or `build.gradle.kts`) and set:
   ```
   minSdk = 24
   ```
4. Install packages and run on your phone:
   ```bash
   flutter pub get
   flutter run
   ```
5. If a package version fails to resolve, run `flutter pub upgrade --major-versions` and fix any small API changes the analyzer reports.

## Current limits / next steps

- Sound types are classified from decibel levels. **Next:** add a YAMNet TensorFlow Lite model (`tflite_flutter`) to name exact sounds (horn, siren, doorbell, dog, baby crying).
- ML Kit's default model gives general labels. **Next:** train a custom model (Roboflow + YOLO → TFLite) for vehicles, stairs, doors and Philippine peso bills.
- Distance is estimated from box size. **Next:** ARCore Depth API for real distance in meters.
- SOS opens the SMS app; the user presses Send. **Next:** Firebase Cloud Messaging push to a caregiver companion app.
- Fall detection works while the app is open. **Next:** Android foreground service.
- Wear OS companion for wrist vibration.

## Testing checklist for the capstone

- Detection accuracy and speed (fps) per object type, indoors and outdoors
- Response time from detection to vibration (target under 200 ms)
- Pattern recognition accuracy with users after the practice session
- Usability testing (SUS questionnaire) with blind, deaf, deafblind and neurodivergent participants through a partner school or PWD organization

---
BSIT Capstone Project, College of ICT, Bulacan State University.
