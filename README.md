# MedScan Pro — FYP

**A Flutter/Firebase medicine verification and scanning application.**

MedScan Pro is a Final Year Project (FYP) that empowers patients to verify medicines using their smartphone camera. It performs OCR-based medicine recognition, DRAP catalog verification, prescription management, medicine reminders, interaction checking, and AI-powered health consultation via MedBot.

---

## Project Structure

```
MedScanPro/                          ← Repository root
├── MedScanPro/
│   └── MedScanPro/
│       ├── medscan_mobile/          ← Flutter Android/iOS app  ← MAIN APP
│       ├── medscan_web/             ← Flutter Web app
│       ├── functions/               ← Firebase Cloud Functions (Node.js)
│       ├── firestore.rules          ← Firestore Security Rules
│       ├── storage.rules            ← Firebase Storage Rules
│       └── firebase.json            ← Firebase project config
├── docs/
│   └── testing/
│       └── phase_4_evidence/        ← Acceptance testing evidence & reports
├── AGENTS.md                        ← AI agent development guidelines
├── CHANGELOG.md                     ← Project changelog
└── README.md                        ← This file
```

---

## Prerequisites

| Tool | Required Version |
|------|-----------------|
| Flutter SDK | `^3.9.0` (Dart `^3.9.0`) |
| Android SDK | API 33+ (Android 13 target), SDK Build Tools 34+ |
| Java JDK | 17 (required for Gradle) |
| Node.js | 18+ (for Firebase Cloud Functions) |
| Firebase CLI | Latest (`npm install -g firebase-tools`) |

Check your environment:

```bash
flutter doctor
java -version
node --version
```

---

## Clone & Setup

### 1. Clone the repository

```bash
git clone https://github.com/qazihasnat1122/MedScan_Pro_FYP.git
cd MedScan_Pro_FYP
```

### 2. Enter the Flutter mobile application

```bash
cd MedScanPro/MedScanPro/medscan_mobile
```

### 3. Install Flutter dependencies

```bash
flutter pub get
```

### 4. Configure Firebase

This project uses Firebase (Auth, Firestore, Storage, Cloud Functions, App Check).

The `google-services.json` (Android) and `firebase_options.dart` are included for the development Firebase project. If you are connecting to your own Firebase project:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an Android app with package name `com.medscanpro.medscan_mobile`.
3. Download `google-services.json` and replace `medscan_mobile/android/app/google-services.json`.
4. Run `flutterfire configure` to regenerate `lib/firebase_options.dart`.
5. Enable **Anonymous Authentication** and **Email/Password Authentication** in Firebase Auth.
6. Deploy Firestore Security Rules: `firebase deploy --only firestore:rules`.

### 5. Configure environment variables

Copy the example file and fill in your API keys:

```bash
cp .env.example .env
```

Required keys in `medscan_mobile/.env`:
- `GEMINI_API_KEY` — Your Google Gemini AI API key
- `PRESCRIPTION_API_URL` — Firebase Cloud Function endpoint
- `MAPBOX_ACCESS_TOKEN` — Mapbox token (for map integration)

> ⚠️ **Never commit `.env` to version control.** The `.gitignore` excludes it automatically.

---

## Running the App

### List connected devices

```bash
flutter devices
```

### Run on a connected device or emulator

```bash
flutter run
```

### Run on a specific device

```bash
flutter run -d <device-id>
```

---

## Unit Tests

```bash
flutter test test/unit/
```

### Run specific OCR and verification tests

```bash
flutter test test/unit/packaging_ocr_parser_test.dart test/unit/verification_and_hologram_test.dart
```

---

## Static Analysis

```bash
flutter analyze
```

Expected result: `No issues found!`

---

## Build APK (Android)

```bash
flutter build apk --debug
```

---

## Firebase Cloud Functions

```bash
cd ../functions
npm install
firebase deploy --only functions
```

---

## Common Setup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `sdk.dir` not found | `local.properties` missing (excluded from git) | Android Studio regenerates it on open, or run `flutter run` once |
| `google-services.json` not found | Firebase not configured | Follow the Firebase setup steps above |
| `No .env file` | Environment file not created | Copy `.env.example` to `.env` and fill in keys |
| `flutter pub get` fails | Flutter SDK version mismatch | Ensure Flutter `^3.9.0` is installed |
| `Gradle build failed` | Java version | Use JDK 17 — check with `java -version` |
| Firebase Auth anonymous disabled | App Check enforcement or project config | Enable Anonymous Auth in Firebase Console → Authentication → Sign-in method |

---

## Acceptance Testing Evidence

Phase 4 acceptance testing results (scanner, authentication, OCR pipeline, catalog matching) are documented in:

```
docs/testing/phase_4_evidence/
├── phase_4_acceptance_report.md   ← Full test report
├── flutter_analyze.log            ← Static analysis results
├── unit_tests.log                 ← Unit test execution log
├── ocr_catalog_matching.txt       ← OCR pipeline results
├── dashboard_screen.png           ← Dashboard screenshot
├── scanner_live.png               ← Scanner viewfinder screenshot
├── scanner_after_shutter.png      ← OCR ambiguity dialog screenshot
└── sample_dialog.png              ← DRAP catalog verification dialog
```

---

## Partner Developer Quick Reference

```bash
# Clone
git clone https://github.com/qazihasnat1122/MedScan_Pro_FYP.git
cd MedScan_Pro_FYP

# Check Flutter setup
flutter doctor

# Install dependencies (run from the Flutter app directory)
cd MedScanPro/MedScanPro/medscan_mobile
flutter pub get

# List devices
flutter devices

# Run app
flutter run

# Run tests
flutter test test/unit/

# Analyze
flutter analyze
```

---

## License

This project is a Final Year Project submission and is not licensed for public redistribution.
