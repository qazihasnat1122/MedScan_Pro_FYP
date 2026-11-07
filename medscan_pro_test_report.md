# MedScan Pro — Test & Build Report (re-audit, 2026-10-22)

All results below are from commands run in this session. Nothing was run on a physical device or emulator; no live Firebase project was contacted.

## 1. Commands and outcomes

| # | Command | Directory | Exit | Summary |
|---|---|---|---|---|
| 1 | `flutter pub get` | medscan_mobile | 0 | dependencies resolved |
| 2 | `flutter analyze --no-fatal-infos` (baseline) | medscan_mobile | 0 | No issues found |
| 3 | `flutter test` (baseline) | medscan_mobile | 0 | 39/39 passed |
| 4 | `flutter analyze --no-fatal-infos` (after fixes, 1st) | medscan_mobile | 1 | 1 warning: unused import in `my_medicines_screen.dart` (caused by my fix) |
| 5 | `flutter test` (after fixes) | medscan_mobile | 0 | **42/42 passed** |
| 6 | `flutter analyze --no-fatal-infos` (after import fix) | medscan_mobile | 0 | No issues found |
| 7 | `flutter build apk --release` | medscan_mobile | 0 | `build\app\outputs\flutter-apk\app-release.apk`, **117,466,490 bytes (≈112 MB)**, 2026-10-22 15:34:40; Gradle 111.7 s |
| 8 | `flutter test` | medscan_web | 0 | **10/10 passed** |
| 9 | `flutter analyze --no-fatal-infos` | medscan_web | (piped; see note) | 33 info-level `withOpacity` deprecations, 0 errors/warnings |
| 10 | `flutter build web --release` | medscan_web | 0 | `build\web` built, 56.5 s compile |

Note on #9: the reported exit code came from a piped command; the analyzer output itself shows only info-level items.

## 2. Test inventory (mobile 42 + web 10 = 52)

Changes vs. previous report (39 mobile): `ai_chat_pharmacist_test.dart` rewritten (3 → 5 tests, now on the real `AiRagService` offline path); `clinical_service_test.dart` +1 (coverage notice); `real_scan_verification_test.dart` and `verification_and_hologram_test.dart` modified (see below).

| Area | Tests | What they actually prove | What they do **not** prove |
|---|---|---|---|
| `AiRagService` offline engine (5) | interaction, missed dose, metformin, unknown-question honesty, packaging tips | Offline replies contain disclaimer, no blockchain/overclaim, unknown questions admit ignorance | Gemini path, clinical correctness, Urdu |
| `ClinicalService` (6) | brand→salt, duplicate salt, aspirin+warfarin, paracetamol+ibuprofen, unmapped notice, single med, coverage notice | The small hand-written rules fire | Completeness/accuracy of drug database |
| Verification (`verification_and_hologram_test`, `real_scan_verification_test`) | green with simulated live record; expired→suspicious; bundled sample batch never green | Engine state logic for 3 scenarios | no-reference, limited, anomaly counts, unconfirmed-field gate, barcode mismatch; real Firestore data |
| OCR parsers (3 + 4) | one pasted pack text, empty, noise; prescription blank/header noise/valid line/name match | No fabrication on empty/noise input | Real camera/ML Kit output, handwriting |
| Pharmacy (5) | list, filter, search, notice, model round-trip | Static list behaves | Any real data, location, permissions |
| Dose scheduling (3) | time parse/sort/rollover helpers | helper maths | actual notifications/alarms |
| Settings/localisation (4), models (3), widget routing (3) | basic | strings present, serialisation, routing with overrides | Urdu quality, auth, Firebase |
| Web (10) | in-memory store tests (Firebase not initialised in tests) | client-side filtering, static DRAP/FBR directory lookup | server-side rules, tenant isolation on Firestore |

Mocks/fakes: web tests use an in-memory store; mobile widget tests override providers; all logic tests are pure Dart with bundled data.

## 3. Important untested scenarios
Firestore rules (no emulator tests, including this session's changes); camera/ML Kit on real images; barcode/DataMatrix; notifications/exact alarms/reboot; Firebase Auth; Gemini calls; location permission (not implemented); offline/online transitions; accessibility/RTL; admin role gating; physical devices.

## 4. Artifact facts
- APK exists at `medscan_mobile\build\app\outputs\flutter-apk\app-release.apk` — 117,466,490 bytes (verified with `Get-Item`).
- Web bundle built to `medscan_web\build\web` (not served/browsed in this session).
- Physical-device testing: **none recorded**.
- `graphify update .` was run in the earlier session; it was **not re-run** after this session's edits (see CHANGELOG).
