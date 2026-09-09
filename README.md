# Aegis — Safe Walk

A personal safety companion app for anyone walking, commuting, or traveling alone. Aegis keeps a live GPS-tracked trip running, watches the phone's motion sensors for signs of a fall or sudden impact, and can alert trusted contacts automatically or via a one-tap SOS button. A safe-route layer helps compare paths, and a compass tool points toward a saved destination.

Built for the Mobile Application Development module — academic MVP.

## Tech Stack

- **Flutter** (Dart) — Android target
- **Firebase** — Authentication, Cloud Firestore, Cloud Messaging
- **Sensors:** accelerometer, gyroscope, magnetometer (`sensors_plus`)
- **Location:** live GPS streaming (`geolocator`)
- **Maps:** `google_maps_flutter`

## Prerequisites

Before you start, make sure you have:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Channel stable)
- [Android Studio](https://developer.android.com/studio) with the Flutter and Dart plugins installed
- Android SDK Command-line Tools (installable via Android Studio → SDK Manager → SDK Tools tab)
- A physical Android device is **strongly recommended** for testing — accelerometer/gyroscope behavior is unreliable on emulators

Run `flutter doctor` after installing to confirm your setup. The Android toolchain line should show a green checkmark (Chrome/Visual Studio warnings can be ignored — this project doesn't target web or Windows desktop).

## Getting Started

```bash
git clone https://github.com/ThathsaraDasun/aegis.git
cd aegis
flutter pub get
flutter run
```


## Configuration

- **minSdkVersion:** 23
- **applicationId:** `com.aegis.safewalk`
- Firebase config (`google-services.json`) must be placed in `android/app/` — request this from the Backend & Alerts lead if you don't have it.

## Team & Roles

| Member | Role |
|---|---|
| Member 1 | Project Lead & SOS System |
| Member 2 | Location & Maps Lead |
| Member 3 | Contacts & Safe Route Lead |
| Member 4 | Backend & Alerts Engineer |
| Member 5 | Compass & Secondary Views |
| Member 6 | QA, Documentation & Defense Lead |

## Branching & Contribution

- Never push directly to `main` — every feature lives on its own branch (`feature/auth-sos`, `feature/location-maps`, `feature/contacts-route`, `feature/backend-alerts`, `feature/compass-activity`).
- Commit messages follow: `feat:`, `fix:`, `chore:`, `docs:`.
- Every merge into `main` goes through a pull request and requires review before merging.

## License

Academic project — Mobile Application Development module.