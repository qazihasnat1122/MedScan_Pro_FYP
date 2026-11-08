# Cloud Functions Deployment Readiness Audit — MedScan Pro

**Document Date:** 2026-11-09  
**Firebase Project:** `medscan-bed48` (Project Number: `589982574266`)  
**Deployment Target:** `extractPrescription` (Cloud Functions v2 HTTPS)  
**Target Region:** `us-central1`  

---

## 1. Executive Summary & Deployment Readiness

### Deployment Readiness Status: **NOT READY (Blocked on Firebase Blaze Plan Upgrade)**
- **Backend Code & Security Architecture:** **READY**
- **Client Integration Contract:** **READY**
- **Google Cloud Platform Infrastructure:** **BLOCKED**
  - Project `medscan-bed48` is currently on the free **Spark** plan.
  - Google Cloud Functions deployment and Google Secret Manager (`secretmanager.googleapis.com`) require the **Blaze (pay-as-you-go)** plan.
  - Command `firebase functions:secrets:get GEMINI_API_KEY` confirmed with:
    > `Error: Your project medscan-bed48 must be on the Blaze (pay-as-you-go) plan to complete this command. Required API secretmanager.googleapis.com can't be enabled until the upgrade is complete.`

---

## 2. Task 1 — Project Audit

### 2.1 Configuration Files Inspected
1. **`firebase.json`** (`MedScanPro/MedScanPro/firebase.json`):
   - Configures `firestore.rules`, `storage.rules`, and `functions` source directory (`functions`).
   - `"ignore"` array correctly excludes `node_modules`, `.git`, `.env*`, `.secret*`.
2. **`.firebaserc`** (`MedScanPro/MedScanPro/.firebaserc`):
   - Previously missing (caused `Error: No active project` when running `firebase use`).
   - Now created mapping `"default": "medscan-bed48"`.
3. **`functions/package.json`**:
   - `engines.node: "20"` (Node.js 20 LTS runtime).
   - Dependencies: `firebase-admin: "^12.1.0"`, `firebase-functions: "^5.0.0"`.
   - Added script: `"test": "node --test test/*.js"`.
4. **`functions/index.js`**:
   - Cloud Functions v2 HTTPS exports: `extractPrescription` and `chatConsultant`.
   - Verified clean syntax: `node --check index.js` passed (exit code 0).
5. **Existing Flutter Integration** (`prescription_ai_service.dart`):
   - Configured endpoint: `https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription`.
   - ID Token acquisition: via `FirebaseAuth.instance.currentUser?.getIdToken()`.
   - Payload format: `{"mimeType": "...", "base64Data": "...", "additionalPagesBase64": [...]}`.
   - Header: `Authorization: Bearer <idToken>`.

---

## 3. Task 2 — Security Audit

1. **Gemini API Key Handling:**
   - Server-side only: Key is never exposed in Flutter code, client assets, or client bundles.
   - Cloud Functions v2 configured with `secrets: ["GEMINI_API_KEY"]` on `extractPrescription`.
   - In production, Cloud Run mounts the secret securely from Secret Manager into `process.env.GEMINI_API_KEY`.
   - In local development, fallback reads from `.env` or `.env.local` (which are gitignored).
2. **Authentication Enforcement:**
   - Every request enforces `req.headers.authorization.startsWith("Bearer ")`.
   - Verified server-side via `admin.auth().verifyIdToken(idToken)`.
   - Missing or expired tokens return `HTTP 401 Unauthorized`.
3. **Privacy & PHI Protection:**
   - No prescription images, patient names, extracted text, or auth tokens are written to logs.
   - Error logs surface high-level HTTP status codes without sensitive request payloads.
4. **Firestore Security Rules:**
   - Preserved unmodified (`firestore.rules`). Prescriptions subcollection strictly enforces authenticated user ownership (`resource.data.userId == request.auth.uid`) and clinical verification flags.

---

## 4. Task 3 — Compatibility Audit

1. **Node.js Runtime:**
   - Declared: Node.js 20 (`"node": "20"`).
   - Local toolchain: Node v24.10.0, npm 11.6.1.
   - Official Firebase Functions v2 support for Node.js 20 confirmed.
2. **Dependencies:**
   - `firebase-admin@^12.1.0` and `firebase-functions@^5.0.0` load cleanly without warnings.
3. **Region Alignment:**
   - Explicitly configured `region: "us-central1"` in `functions/index.js` for `extractPrescription`.
   - Guarantees Cloud Functions URL matches client default `https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription`.

---

## 5. Task 4 — Function Validation

### 5.1 Endpoint Contract
- **Export:** `exports.extractPrescription = onRequest({ ... }, handler)`
- **HTTP Method:** POST only (`HTTP 405` for GET/PUT/DELETE)
- **Input Types:** `image/jpeg`, `image/png`, `image/webp`, `application/pdf` (`HTTP 400` for invalid types)
- **Output Schema:**
```json
{
  "rawText": "string",
  "prescriptionDate": "string",
  "medicines": [
    {
      "medicineName": "string",
      "brand": "string",
      "strength": "string",
      "dosageInstructions": "string",
      "route": "string",
      "frequency": "string",
      "timing": "string",
      "duration": "string",
      "durationDays": null,
      "quantity": "string",
      "specialInstructions": "string",
      "confidence": "high | medium | low",
      "uncertainFields": []
    }
  ]
}
```

### 5.2 Model Fallback Resilience
- Added multi-model fallback chain in `extractPrescription`:
  - `process.env.GEMINI_MODEL` (if set)
  - `gemini-1.5-flash`
  - `gemini-2.0-flash`
  - `gemini-flash-latest`
- Automatically retries next model on HTTP 404/503 upstream responses before returning 502.

---

## 6. Task 5 — Testing & Verification

| Test Suite | Command | Exit Code | Result | Evidence File |
|---|---|---|---|---|
| Flutter Static Analysis | `flutter analyze --no-pub` | 0 | **No issues found (36.1s)** | `flutter_analyze.log` |
| Flutter Prescription Tests | `flutter test test/unit/prescription_*` | 0 | **13/13 PASSED** | `prescription_tests.log` |
| Backend Endpoint Unit Tests | `npm test` (in `functions/`) | 0 | **5/5 PASSED** | `functions_contract_tests.log` |
| Firebase CLI Project Check | `firebase use` | 0 | **medscan-bed48 active** | Terminal output |
| Firebase Secret Manager Check | `firebase functions:secrets:get` | 1 | **BLOCKED (Requires Blaze Plan)** | Documented above |

---

## 7. Files Modified or Created

1. **`MedScanPro/MedScanPro/.firebaserc`** (Created)
   - Configures default Firebase project alias (`medscan-bed48`).
2. **`MedScanPro/MedScanPro/functions/index.js`** (Modified)
   - Added `region: "us-central1"` and `secrets: ["GEMINI_API_KEY"]` to `extractPrescription` and `chatConsultant`.
   - Added resilient model fallback chain to `extractPrescription`.
3. **`MedScanPro/MedScanPro/functions/package.json`** (Modified)
   - Added `"test": "node --test test/*.js"` script.
4. **`MedScanPro/MedScanPro/functions/test/extract_prescription_test.js`** (Created)
   - Added contract & request validation unit tests (5 test cases).
5. **`docs/testing/phase_5_evidence/functions_contract_tests.log`** (Created)
   - Log of 5 passing backend tests.
6. **`docs/testing/phase_5_evidence/cloud_functions_deployment_audit.md`** (Created)
   - This audit report.

---

## 8. Exact Step-by-Step Deployment Instructions (When Blaze Plan is Active)

Once the Firebase project owner upgrades `medscan-bed48` to the Blaze plan (https://console.firebase.google.com/project/medscan-bed48/usage/details):

### Step 1: Set Secret in Google Secret Manager
Run from `MedScanPro/MedScanPro`:
```bash
firebase functions:secrets:set GEMINI_API_KEY --project medscan-bed48
```
*(Enter your Gemini API key when prompted. The key is securely encrypted in Google Cloud Secret Manager.)*

### Step 2: Deploy the Function
Run from `MedScanPro/MedScanPro`:
```bash
firebase deploy --only functions:extractPrescription --project medscan-bed48
```

### Step 3: Verify Deployment
Verify endpoint is live and returning HTTP 405 for GET (proving active HTTPS endpoint):
```bash
curl -i https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription
```
*(Expected: `HTTP/2 405` with `{"error":"Method not allowed. Use POST."}`.)*
