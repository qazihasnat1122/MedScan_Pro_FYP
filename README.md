# MedScan Pro — FYP

**A Flutter/Firebase medicine verification and safety application.**

MedScan Pro is a Final Year Project (FYP) that empowers patients to verify medicines using their smartphone camera. It performs on-device OCR packaging recognition, DRAP verified catalog matching, prescription management, medicine reminders, drug interaction checking, nearby pharmacy discovery, and AI health consultation.

---

## ⚡ Quickstart for Collaborators (Zero-Configuration)

No personal API keys or configuration files are required to build and run the app. All essential services work out-of-the-box or fall back gracefully to local offline engines:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/qazihasnat1122/MedScan_Pro_FYP.git
   cd MedScan_Pro_FYP
   ```

2. **Navigate to the Flutter mobile application:**
   ```bash
   cd MedScanPro/MedScanPro/medscan_mobile
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Connect an Android device or start an emulator and run:**
   ```bash
   flutter run
   ```

That's it! The app builds and runs without entering any keys.

---

## 🔍 Feature & Service Status Overview

| Module / Feature | Requires Personal Key? | How It Works Out-of-the-Box |
|---|:---:|---|
| **App Launch & Onboarding** | ❌ No | Fully operational. |
| **Authentication (Demo & Email)** | ❌ No | Connects to configured Firebase project (`medscan-bed48`). Quick Demo Access logs in anonymously. |
| **Medicine Packaging Scanner** | ❌ No | Runs 100% on-device ML Kit OCR (`Latn_ctc/optical/lstm_model.fb`) and matches against local DRAP catalog. |
| **Drug Interaction Checker** | ❌ No | Runs 100% on-device clinical knowledge base (`ClinicalService`). |
| **Medicine Reminders** | ❌ No | Uses native Android dose alarms & local notifications (`NotificationService`). |
| **Nearby Pharmacies** | ❌ No | Pre-configured with a public Mapbox token (`pk.*`) for Search Box POI lookup, and automatically falls back to OpenStreetMap Overpass & Nominatim without any key. |
| **Prescription Processing** | ❌ No | Supports On-Device OCR (`PackagingOcrParser`) and manual confirmation. Optional server-side AI extraction requires deployed Cloud Function. |
| **MedBot (Health Assistant)** | ❌ No (Optional) | Built-in offline clinical reasoning engine handles health queries. If you wish to use live Google Gemini AI, enter your key via the in-app key icon or set `GEMINI_API_KEY` in `.env`. |

---

## Project Structure

```
MedScan_Pro_FYP/
├── MedScanPro/
│   └── MedScanPro/
│       ├── medscan_mobile/          ← Main Flutter Android/iOS application
│       ├── medscan_web/             ← Flutter Web administration portal
│       ├── functions/               ← Firebase Cloud Functions backend (Node.js)
│       ├── firestore.rules          ← Firestore Security Rules
│       ├── storage.rules            ← Firebase Storage Security Rules
│       └── firebase.json            ← Firebase project configuration
├── docs/
│   └── testing/
│       └── phase_4_evidence/        ← Phase 4 acceptance testing evidence & reports
├── AGENTS.md                        ← AI agent development & Ponytail guidelines
├── CHANGELOG.md                     ← Project changelog
└── README.md                        ← This file
```

---

## Prerequisites

| Tool | Required Version |
|------|-----------------|
| Flutter SDK | `^3.9.0` (Dart `^3.9.0`) |
| Android SDK | API 33+ (Android 13 target), SDK Build Tools 34+ |
| Java JDK | 17 (required for modern Gradle) |
| Node.js | 18+ (only if deploying Firebase Cloud Functions) |

Verify your environment:
```bash
flutter doctor
java -version
```

---

## Optional: Live Gemini AI Configuration

If you want live Google Gemini AI responses instead of the offline clinical reasoning engine:

1. Copy `.env.example` to `.env` in `medscan_mobile/`:
   ```bash
   cp .env.example .env
   ```
2. Paste your Google Gemini API key:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```
3. Alternatively, launch the app, open **MedBot / AI Chat**, tap the **Key icon** in the top bar, and paste your key for the current session.

---

## Running Tests & Analysis

All commands should be executed from `MedScanPro/MedScanPro/medscan_mobile`:

```bash
# Static analysis (verifies 0 errors, 0 warnings)
flutter analyze

# Run all unit and widget tests (126 tests)
flutter test test/unit/

# Run scanner and packaging OCR parser tests
flutter test test/unit/packaging_ocr_parser_test.dart test/unit/verification_and_hologram_test.dart

# Run nearby pharmacy provider comparison tests
flutter test test/unit/nearby_pharmacy_test.dart
```

---

## Common Setup Issues & Solutions

| Issue | Cause | Solution |
|---|---|---|
| `sdk.dir` not found | `local.properties` is machine-specific | Run `flutter run` or open the project once in Android Studio; it will auto-generate `android/local.properties`. |
| Java version error | Gradle incompatible with Java 21+ | Install and configure JDK 17 as `JAVA_HOME`. |
| Firebase anonymous login failed | Emulator network connectivity | Ensure your emulator has working internet access. |
| Overpass 502 / Mapbox rate limit | Upstream server traffic | MedScan Pro automatically retries fallback endpoints (Mapbox → Overpass → Nominatim). |

---

## Acceptance Testing Evidence

Phase 4 acceptance testing logs, test outputs, and screenshots are recorded in [`docs/testing/phase_4_evidence/`](docs/testing/phase_4_evidence/):
- `phase_4_acceptance_report.md`: Detailed test report.
- `flutter_analyze.log`: Clean static analysis report.
- `unit_tests.log`: Complete 16/16 scanner and OCR test suite output.
- `ocr_catalog_matching.txt`: Runtime OCR and DRAP catalog matching breakdown.
- `scanner_live.png`: Camera viewfinder and permission screenshot.
- `dashboard_screen.png`: Authenticated dashboard screenshot.

---

## License

This project is a Final Year Project submission and is not licensed for public redistribution.
