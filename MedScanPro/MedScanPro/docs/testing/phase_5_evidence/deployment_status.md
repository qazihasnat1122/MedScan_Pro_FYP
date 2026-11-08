# MedScan Pro — Cloud Functions Deployment Status

**Document Date:** 2026-11-09  
**Firebase Project:** `medscan-bed48`  
**Target Function:** `extractPrescription` (Cloud Functions v2 HTTPS)  
**Target Region:** `us-central1`  
**Deployment Tool:** Firebase CLI v15.24.0  

---

## 1. Deployment Readiness Verdict

### **STATUS: BLOCKED (Action Required by Firebase Project Owner)**

| Category | Status | Details |
|---|---|---|
| **Backend Code Implementation** | **READY** | HTTPS v2 export, strict schema validation, multi-model fallback chain (`gemini-1.5-flash`, `gemini-2.0-flash`, `gemini-flash-latest`), unit contract tests passing (5/5). |
| **Security Architecture** | **READY** | `secrets: ["GEMINI_API_KEY"]` declared in function definition. Cloud Run mounts secret to `process.env.GEMINI_API_KEY`. No secrets in source code. |
| **Authentication Enforcement** | **READY** | Firebase Auth ID token verified via `admin.auth().verifyIdToken()`. |
| **Firebase Project Linkage** | **READY** | `.firebaserc` configured with `"default": "medscan-bed48"`. |
| **Google Cloud Billing Plan** | **BLOCKED** | Project `medscan-bed48` is on the free **Spark** plan. Cloud Functions v2 and Google Secret Manager require the pay-as-you-go **Blaze** plan. |

---

## 2. Google Cloud Platform Error Log

Running the Secret Manager check command:
```bash
firebase functions:secrets:get GEMINI_API_KEY --project medscan-bed48
```
Produced the following error:
```
Error: Your project medscan-bed48 must be on the Blaze (pay-as-you-go) plan to complete this command. Required API secretmanager.googleapis.com can't be enabled until the upgrade is complete. To upgrade, visit the following URL:

https://console.firebase.google.com/project/medscan-bed48/usage/details
```

---

## 3. Policy & Guardrails Enforced
- **Zero Automatic Upgrades**: As instructed, billing was NOT activated and no automatic deployment was attempted.
- **Client-Side Fallback Protected**: The mobile app gracefully handles the undeployed backend (HTTP 404/503) by prompting the user with **Try On-Device OCR** (using local Google ML Kit) and **Review Manually**, ensuring full usability on offline and free tier environments without exposing API keys.

---

## 4. Exact Commands Required for Deployment (Post-Billing Upgrade)

Once the project owner links a billing account at [Firebase Usage Details](https://console.firebase.google.com/project/medscan-bed48/usage/details):

### Step 1 — Store Secret in Google Secret Manager
Run from `MedScanPro/MedScanPro`:
```bash
firebase functions:secrets:set GEMINI_API_KEY --project medscan-bed48
```
*(Enter your Google Gemini API key when prompted. The key is encrypted in Google Secret Manager).*

### Step 2 — Deploy the Prescription Extraction Function
Run from `MedScanPro/MedScanPro`:
```bash
firebase deploy --only functions:extractPrescription --project medscan-bed48
```

### Step 3 — Verify the Live Endpoint
```bash
curl -i https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription
```
*(Expected: `HTTP 405 Method Not Allowed` with body `{"error":"Method not allowed. Use POST."}`, confirming the HTTPS endpoint is live and responding).*
