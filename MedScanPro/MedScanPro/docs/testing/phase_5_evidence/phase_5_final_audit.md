# Phase 5 — Prescription Management: Final Acceptance & Security Audit Report

**Audit Date:** 2026-11-09  
**Engineer:** Qazi Muhammad Hasnat Javed  
**Project:** MedScan Pro (FYP)  
**Firebase Project:** `medscan-bed48`  
**Git Repository:** https://github.com/qazihasnat1122/MedScan_Pro_FYP  
**Branch:** `main`  

---

## 1. Executive Summary

| Verification Category | Status | Details |
|---|---|---|
| **Prescription Workflow Implementation** | **PASS** | Complete pipeline: Upload → Consent → Extraction → Review → Save → History → Reminders. |
| **Security & Key Architecture** | **PASS** | Zero Gemini API keys in Flutter client; direct client-side fallback removed; Secret Manager configured; token verification active; Firestore rules intact. |
| **Flutter Unit & Widget Tests** | **PASS** | 13/13 passed (exit code 0). Anti-fabrication, parsing, validation, duplicate prevention, reminders. |
| **Backend Endpoint Contract Tests** | **PASS** | 5/5 passed (exit code 0). HTTP methods, Bearer auth, payload bounds, MIME types, clinical schema. |
| **Static Code Analysis** | **PASS** | `flutter analyze --no-pub` reported 0 issues (exit code 0). |
| **Cloud Functions Deployment** | **BLOCKED** | Project `medscan-bed48` requires Firebase Blaze plan to enable Secret Manager and Cloud Functions. |
| **Physical Hardware Testing** | **NOT TESTED** | `adb devices` shows no hardware device connected. |

---

## 2. Objective 1 — Complete Workflow Verification

The end-to-end prescription management pipeline was audited and verified against the production specifications:

1. **Input & Ingestion (`prescription_upload_screen.dart`):**
   - **Camera:** Captures live images via `ImagePicker`.
   - **Gallery:** Selects stored JPEG/PNG images.
   - **PDF Import:** Native document picker channel imports multi-page PDF files with page count inspection and page navigation.
   - **Compression:** High-resolution images (> 350 KB) are automatically downscaled via native Android Bitmap compression before upload, preventing broken pipes.
   - **File Validation:** Corrupt, 0-byte, or unsupported files throw `PrescriptionFileException` and display user-friendly error banners.

2. **External AI Consent Guard:**
   - Explicit `AlertDialog` presented before any document leaves the device.
   - Discloses processing via Google Gemini AI.
   - User cancellation aborts network transmission and resets state cleanly.

3. **Secure Extraction & Multi-Tier Fallback (`prescription_ai_service.dart`):**
   - **Tier 1 (Production Backend):** HTTPS POST to `https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription` with Firebase Auth ID token.
   - **Tier 2 (On-Device OCR Fallback):** When backend is unreachable (HTTP 404/503), the user can tap "Try On-Device OCR" to extract visible text locally via Google ML Kit Text Recognition with `PrescriptionParser.parse()`.
   - **Tier 3 (Manual Entry):** "Review Manually" opens the review screen with the document preview side-by-side for manual transcription.

4. **Review & Clinical Correction (`prescription_review_screen.dart`):**
   - Side-by-side comparison with the original image / PDF preview.
   - Anti-fabrication: Raw extraction items start with `isConfirmed = false`.
   - Missing fields (`uncertainFields`) are highlighted in amber.
   - Inline edit dialog permits full field correction (medicine name, brand, strength, frequency, timing, duration).
   - Validation guard blocks confirmation if medicine name is blank.

5. **History & Persistence (`MedicationRepository` & `RecordsScreen`):**
   - Saves confirmed prescriptions to Firestore collection `prescriptions`.
   - Idempotent: `_sessionPrescriptionId` prevents duplicate writes on repeated button taps.
   - Per-user ownership isolation enforced by user UID scoping and Firestore rules.
   - Records screen provides full history view with document viewer and deletion actions.

6. **Medicine Reminders (`NotificationService`):**
   - Optional reminder sheet pre-fills medicine name, strength, and frequency.
   - PRN ("as needed") and tapering schedules default to disabled to prevent unintended alarms.
   - User must explicitly choose clock times; no clock times are assumed from "twice daily".
   - Deterministic notification IDs prevent duplicate alarms on edit.

---

## 3. Objective 2 — Security & Key Management Audit

1. **Client-Side Secret Removal:**
   - Audited `_defaultHttpTransport` in `prescription_ai_service.dart`.
   - Removed direct client-side Gemini fallback calls that attempted to read `.env` / runtime keys from Flutter when the Cloud Function was 404.
   - All prescription AI extraction is now strictly routed through the secure Cloud Function proxy.
   - Zero Google Gemini API keys are bundled or exposed in the mobile client code.

2. **Backend Secret Manager Configuration (`functions/index.js`):**
   - Function export configured with `secrets: ["GEMINI_API_KEY"]` and `region: "us-central1"`.
   - In production, Cloud Run mounts the secret securely into `process.env.GEMINI_API_KEY`.
   - `firebase.json` ignore list excludes `.env*` and `.secret*` files from deployment.

3. **Authentication & Token Verification:**
   - Server-side verification via `admin.auth().verifyIdToken(idToken)`.
   - Enforces Bearer token presence; rejects with HTTP 401 if missing or invalid.

4. **Payload Bounds & Privacy (PHI):**
   - Request body validated for `mimeType` and `base64Data`.
   - Zero patient health information, prescription text, images, or tokens are logged on the server or client.
   - Firestore security rules (`firestore.rules`) strictly require user authentication, UID matching, and `isConfirmedByUser == true`.

---

## 4. Objective 3 — Deployment Status & Blocker Analysis

### Status: **BLOCKED (Requires Firebase Blaze Plan Upgrade)**

- **Investigation Result:**
  Running `firebase functions:secrets:get GEMINI_API_KEY --project medscan-bed48` returned:
  ```
  Error: Your project medscan-bed48 must be on the Blaze (pay-as-you-go) plan to complete this command. Required API secretmanager.googleapis.com can't be enabled until the upgrade is complete. To upgrade, visit the following URL:

  https://console.firebase.google.com/project/medscan-bed48/usage/details
  ```
- **Action Required:**
  The project owner must link a billing account on the Firebase Console. Note that Cloud Functions and Secret Manager include a generous free tier (2M Cloud Function invocations/month and 40K secret versions/month).
- **Exact Deployment Commands (Once Upgraded):**
  ```bash
  cd MedScanPro/MedScanPro
  firebase functions:secrets:set GEMINI_API_KEY --project medscan-bed48
  firebase deploy --only functions:extractPrescription --project medscan-bed48
  ```

---

## 5. Objective 4 — Physical Hardware Testing Status

### Status: **NOT TESTED (Hardware Unavailable)**

- `adb devices` execution confirmed no physical device or emulator is currently attached.
- In accordance with Ponytail engineering standards, test results are never fabricated.
- A standardized 11-point acceptance protocol has been prepared in [`physical_device_test_checklist.md`](./physical_device_test_checklist.md) ready for execution once a physical handset is connected via USB.

---

## 6. Objective 5 — Test Execution Evidence

### 6.1 Flutter Static Analysis
- **Command:** `flutter analyze --no-pub`
- **Exit Code:** `0`
- **Output:** `No issues found! (ran in 69.6s)`
- **Log:** [`flutter_analyze.log`](./flutter_analyze.log)

### 6.2 Flutter Prescription Unit & Widget Tests
- **Command:** `flutter test test/unit/prescription_parser_test.dart test/unit/prescription_workflow_test.dart --no-pub`
- **Exit Code:** `0`
- **Duration:** 4.2s
- **Result:** **13/13 PASSED**
- **Log:** [`prescription_tests.log`](./prescription_tests.log)

### 6.3 Backend Endpoint Contract Tests
- **Command:** `npm test` (in `MedScanPro/MedScanPro/functions`)
- **Exit Code:** `0`
- **Result:** **5/5 PASSED**
- **Log:** [`functions_contract_tests.log`](./functions_contract_tests.log)

---

## 7. Objective 6 — Files Changed & Git Hygiene

### Files Modified / Created
| File | Status | Description |
|---|---|---|
| [`medscan_mobile/lib/services/prescription_ai_service.dart`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/medscan_mobile/lib/services/prescription_ai_service.dart) | Modified | Removed direct client-side Gemini fallback; enforced strict backend proxy routing. |
| [`functions/index.js`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/functions/index.js) | Modified | Configured `region: "us-central1"`, `secrets: ["GEMINI_API_KEY"]`, and multi-model fallback chain. |
| [`functions/package.json`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/functions/package.json) | Modified | Added `"test": "node --test test/*.js"` script. |
| [`functions/test/extract_prescription_test.js`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/functions/test/extract_prescription_test.js) | Created | Backend contract and validation test suite. |
| [`.firebaserc`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/.firebaserc) | Created | Configured default project alias (`medscan-bed48`). |
| [`docs/testing/phase_5_evidence/deployment_status.md`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/docs/testing/phase_5_evidence/deployment_status.md) | Created | Deployment status and Blaze plan requirement documentation. |
| [`docs/testing/phase_5_evidence/physical_device_test_checklist.md`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/docs/testing/phase_5_evidence/physical_device_test_checklist.md) | Created | Hardware test checklist with NOT TESTED classifications. |
| [`docs/testing/phase_5_evidence/phase_5_final_audit.md`](file:///d:/user/StudioProjects/MedScanPro/MedScanPro/MedScanPro/docs/testing/phase_5_evidence/phase_5_final_audit.md) | Created | Master final acceptance report. |

### Git Hygiene & Secret Protection
- Confirmed no `.env`, service-account JSON, keystores, or API keys are staged.
- Working tree verified clean via `git status`.
