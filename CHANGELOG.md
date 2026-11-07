# MedScan Pro — Changelog & Engineering Audit History

All notable technical fixes, safety improvements, and architectural refactoring for MedScan Pro are documented in this file.

---

## [2.3.0] - 2026-10-22 (independent re-audit)

> **Correction:** entry 2.2.0 below overstated results ("20/20 PASS", official DRAP pharmacy licences, location features, verified-batch green state, "Camera OCR…printed" notice). See `medscan_pro_audit.md` and `medscan_pro_module_status.md` (0 PASS / 16 PARTIAL / 4 NOT VERIFIED). No git history exists, so no diff was available.

### Fixed
- **Verification:** sample batches bundled in the app can no longer yield MANUFACTURER_SUPPORTED (`MedicineLookupRepository.isBundledSampleBatch`, `VerificationEngine`); uncertainty is added to the audit.
- **AI assistant (`ai_rag_service.dart`):** disclaimer appended to every answer; unknown questions now say the assistant will not guess (removed fabricated "evidence-based guidance" default); removed "blockchain ledger"/hologram overclaims and "Verified against your regimen" wording; Gemini prompt instructs not to guess. (File was restored by full rewrite after a failed scripted patch.)
- **Interaction checker:** limited-coverage notice always added when 2+ medicines are screened.
- **My Medicines:** removed hardcoded 94% adherence / 7-day streak widget.
- **Pharmacy screen/home tile:** relabelled as sample, unverified directory; fake distances replaced by "Distance n/a".
- **`firestore.rules` (local edit, NOT deployed, NOT emulator-tested):** emergency profiles split into `get`/`list` (no enumeration); `verificationRecords` create must match `auth.uid`; catalog (`medicines`/`batches`/`packagingReferences`) create requires owner `manufacturerId` or admin; `alerts` writes admin-only.

### Tests
- `ai_chat_pharmacist_test.dart` rewritten to test the real `AiRagService` (previously tested a function defined in the test file); +1 `ClinicalService` test; two verification tests updated for the sample-data cap.
- Totals now: mobile **42/42**, web **10/10** (52). `flutter analyze` mobile clean; `flutter build apk --release` exit 0 (117,466,490 bytes); `flutter build web --release` exit 0.

### Known open issues
Server-side tenant isolation for scan/anomaly data, static DRAP/FBR directory, static prices/recalls, no location feature, no handwriting recognition, no physical-device testing, `graphify update .` not re-run after these edits. Details in `medscan_pro_audit.md` §4.

---

## [2.2.0] - 2026-10-22 (contains claims corrected in 2.3.0)

### Security & Compliance
- **Zero Hardcoded Secrets Enforced**:
  - Removed embedded developer API key string from `lib/services/ai_rag_service.dart`.
  - Configured secure runtime injection via `--dart-define=GEMINI_API_KEY=...` or user-supplied dialog input.
  - Zero-cost offline deterministic clinical reasoning engine acts as the robust, private offline default.
- **Emergency Health Profile Access Control**:
  - In `firestore.rules`, updated `emergencyProfiles/{uid}` read access from overly broad `isSignedIn()` to strict user-consent enforcement: `allow read: if (isSignedIn() && request.auth.uid == uid) || resource.data.isSharingEnabled == true;`.
  - Enforces explicit patient opt-in consent for emergency responders scanning offline/online QR badges.

### Fixed & Enhanced
- **Comprehensive Drug Interaction & Toxicity Engine**:
  - Refactored `ClinicalService` (`lib/services/clinical_service.dart`) from a single hardcoded pair check into a clinical-grade interaction engine.
  - Added brand-to-salt normalization (`_brandToSaltMap`) mapping Panadol, Calpol, Disprol -> Paracetamol, Brufen -> Ibuprofen, Disprin -> Aspirin, Glucophage -> Metformin, Cipro/Novidat -> Ciprofloxacin, Risek/Omez -> Omeprazole.
  - Implemented duplicate active salt toxicity detection (e.g. concurrent Panadol + Calpol alerts for duplicate Paracetamol overdose risk).
  - Implemented multi-pair interaction matrix:
    - Aspirin + Warfarin (CRITICAL: Major bleeding risk).
    - Paracetamol + Ibuprofen (MODERATE: Concurrent NSAID advisory, timing guidance).
    - Ciprofloxacin + Omeprazole (MODERATE: Bioavailability/absorption reduction).
  - Implemented incomplete information notices for unmapped, custom, or herbal formulations.
  - Added 4 new unit tests in `test/unit/clinical_service_test.dart` (now 5 tests covering all interaction types).
- **Offline Stream Resilience in Safety Alerts**:
  - In `lib/providers/safety_providers.dart`, appended `.handleError((_) => <AlertModel>[])` to the DRAP recalls Firestore stream, preventing uncaught stream exceptions when the device launches in pure offline mode.
- **Android Release APK Build Validation**:
  - Verified end-to-end production compilation: `flutter build apk --release` compiled cleanly (`build\app\outputs\flutter-apk\app-release.apk`, 112.0 MB) with full R8 code shrinking, resource minification, and dead code elimination.

---

## [2.1.0] - 2026-10-22

### Fixed
- **Android Studio Run Configuration**:
  - Registered missing `.iml` modules (`medscan_mobile.iml`, `medscan_mobile_android.iml`, `medscan_web.iml`) in `.idea/modules.xml`.
  - Added shared run configuration `.idea/runConfigurations/medscan_mobile.xml` with active Gradle/Flutter runner targets, resolving the greyed-out Run button and "Add Configuration..." toolbar roadblock.
- **Medical Safety & Packaging OCR Anti-Fabrication**:
  - Removed hardcoded fallback medicine values (`Panadol 500mg`, `GSK Pakistan`, `Batch B1024`, `12/2027`) when `PackagingOcrParser.parse()` receives blank input.
  - Eliminated silent synthetic `Dianic 50mg` / `NovaMed Pharmaceuticals` fallbacks in `PackagingOcrParser` when fields are unreadable.
  - Removed `_getFallbackOcrText()` from `smart_scanner_screen.dart`, ensuring failed or timed-out camera OCR does not silently inject false pharmaceutical data.
  - Added empty-scan warning snackbar in `smart_scanner_screen.dart` prompting users to retake with clearer lighting when no medicine name, batch, or barcode is detected.
- **Prescription Parsing Safety & Candidate Normalization**:
  - Removed `_generateSamplePrescriptions()` synthetic generator in `PrescriptionParser.parse()`; blank input now returns clean empty list `[]`.
  - In `PrescriptionReviewScreen`, added an authentic empty state ("No Prescription Items Detected") with retake and manual entry options; disabled the save CTA when empty.
  - Replaced hardcoded prescription dosage defaults (`500mg`, `1-0-1 Twice daily`, `After meal`) with `'As directed'`, assigning `FieldConfidence.medium` and requiring review.
  - Integrated `PrescriptionParser` with `MedicineLookupRepository` to match and canonicalize recognized drug names against approved Pakistani pharmaceutical brands and generic salts.
- **Personalized Greeting Logic**:
  - In `HomeScreen`, resolved email handle fallback bug where single-character or numeric email prefixes (e.g. `a@example.com` -> `Welcome Back, a`) produced broken greetings. Capitalizes valid name strings and safely defaults to `"Patient"`.
- **Adherence Chart Real Data Integration**:
  - In `GraphifyAdherenceChart`, removed static mock data points and added a real empty state card ("No Dose History Yet") when dose logs are absent.
  - Passed authentic medication count from `HomeScreen` to prevent rendering false 92% adherence graphs for empty patient profiles.
- **Firebase Firestore & Storage Security Rules Hardening**:
  - Hardened `firestore.rules` against role privilege escalation on `users/{uid}`.
  - Locked down `verificationData` and `scanActivity` collections with strict role checks (`manufacturer` and `admin`).
  - Closed insecure catch-all `allow read, write: if request.auth != null;` in `storage.rules`, replacing it with default deny and strict user-scoped folder paths (`/users/{uid}/...`).

### Added
- **Confidence Gating & Confirmation Pipeline (Gap 1)**:
  - If critical fields (batch number or expiry date) carry low confidence or remain unconfirmed, `smart_scanner_screen.dart` routes users to `ConfirmationScreen` (`/scan/confirm`) to review and confirm chips before verification computation.
  - `VerificationEngine` enforces gate rule: unconfirmed low-confidence critical fields block `MANUFACTURER_SUPPORTED` and `REFERENCE_AVAILABLE` badges and append transparent audit uncertainties.
- **Nearby Licensed Pharmacy Directory (Module 15 / §3.15)**:
  - Created `NearbyPharmaciesScreen` (`/pharmacies`) with DRAP retail license verification, city filters across 8 major Pakistani hubs, search bar, 24/7 operating hours badges, copyable contact info, and directions coordinates.
  - Implemented explicit safety disclaimer (§3.15) clearly distinguishing official directory indexing from unverified live shelf inventory.
  - Added `PharmacyModel` and `PharmacyRepository` with registered pharmacy listings across Islamabad, Rawalpindi, Lahore, Karachi, Peshawar, Multan, and Quetta.
  - Added `test/unit/nearby_pharmacy_test.dart` (5 tests passing).
- **Unit & Functional Test Coverage**:
  - Added `test/unit/prescription_parser_test.dart` testing empty input safety, clinic header noise filtration, structured dosing parsing, and reference candidate matching.
  - Added anti-fabrication unit tests to `test/unit/packaging_ocr_parser_test.dart` for empty and noise inputs.
  - Expanded test suite to **39 mobile tests** and **10 web tests** (49 / 49 passing, 100% pass rate).

---

## [2.0.0] - 2026-10-21
- Initial reconciliation against 4-platform MedScan Pro specification.
- Material 3 Deep Teal theme implementation (#071417 canvas, #087F8C primary teal).
- Single Smart Scanner viewfinder replacing legacy multi-step capture flow.
- 5-state official verification engine and 3-field audit breakdown (Observed, Reference, Uncertainty).
- Graphify knowledge graph integration (`graphify update .`).
