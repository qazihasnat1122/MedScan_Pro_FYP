# MedScan Pro — System Architecture & Technical Specification

## 1. Executive Summary & Purpose
MedScan Pro is a patient-safety-focused, offline-first mobile application (Flutter Android) and regulatory web portal (Flutter Web) designed for medicine verification, anti-counterfeiting tracking, prescription management, and clinical guidance tailored for Pakistan's pharmaceutical market.

---

## 2. Core Architectural Pillars

### 2.1 Offline-First Clinical Resilience
- **Essential Verification & Reference**: The mobile application must operate in low-connectivity clinics and rural pharmacies. Lookups for verified drugs, active ingredients, dosage forms, and reference prices run against an embedded local reference repository (`MedicineLookupRepository`).
- **Zero Hidden API Dependencies**: Core OCR parsing, dosage schedule computation, drug-drug interaction screening, and emergency profile access do not require network roundtrips.
- **Firebase Role**: Cloud Firestore and Firebase Authentication provide asynchronous synchronization, scan telemetry, user dose tracking across devices, and regulatory incident reporting, but are never blockers for immediate offline safety checks.

### 2.2 Medical Safety & Anti-Fabrication Mandate
- **No Hallucinated Data**: The system strictly prohibits synthetic fallbacks for brand names, batch numbers, expiry dates, or DRAP registration codes.
- **Explicit Low-Confidence Handling**: If OCR recognition fails or falls below threshold certainty, fields remain empty and are presented to the patient/clinician as editable action chips.
- **Gatekeeper Verification Rule**: Unconfirmed low-confidence critical fields (Batch Number, Expiry Date) are categorically barred from generating `MANUFACTURER_SUPPORTED` or `REFERENCE_AVAILABLE` verification badges.

---

## 3. Component & Service Architecture

### 3.1 Mobile Architecture (`medscan_mobile`)
```
lib/
├── core/
│   ├── routing/          # GoRouter with bottom navigation shell & deep link handling
│   ├── theme/            # Material 3 Deep Teal theme (#071417 canvas, #087F8C primary)
│   └── localization/     # Dual English / Urdu localization with AppStrings
├── features/
│   ├── auth/             # Biometric & Firebase Authentication flows
│   ├── home/             # Daily dose glance, quick actions, authentic adherence chart
│   ├── scan/             # Single Smart Scanner, Confirmation screen, Bottom Sheet
│   ├── prescriptions/    # Prescription OCR parser, structured review & scheduler
│   ├── medications/      # Patient medication cabinet & adherence history
│   ├── emergency/        # Offline-accessible Emergency Medical ID
│   ├── chatbot/          # Local rule-based AI clinical pharmacist guidance
│   └── settings/         # Language, dark mode, privacy & DRAP portal shortcuts
├── services/
│   ├── packaging_ocr_parser.dart   # Deterministic packaging OCR tokenizer & cleaner
│   ├── prescription_parser.dart    # Clinical prescription parser with noise filter
│   ├── verification_engine.dart    # 5-state official verification & 3-part audit engine
│   ├── notification_service.dart   # Flutter local notifications & exact alarm scheduling
│   └── verification_service.dart   # Firestore telemetry & suspicious incident reporting
└── repositories/
    ├── medicine_lookup_repository.dart  # Offline reference database & Firestore sync
    └── medication_repository.dart       # User prescription & medication records
```

### 3.2 Single Smart Scanner Pipeline
1. **Live Viewfinder**: Real-time barcode & DataMatrix detection via `MobileScanner` controller.
2. **Single Camera Capture**: One high-resolution frame is captured and passed to `OcrService` (Google ML Kit Text Recognition).
3. **Cleaning & Tokenization**: `PackagingOcrParser` removes screen/terminal noise, extracts brand name, active generic salt, strength, dosage form, batch number, dates, price, and regulatory stamps.
4. **Dual-Check Gating**:
   - If both batch and expiry are unreadable on the front, user is prompted to capture the other side.
   - If critical fields have low OCR confidence, user is routed to `/scan/confirm` to confirm or edit values before verification.
5. **Verification Engine Execution**: Matches extracted parameters against manufacturer vaults, computes risk score and anomaly scan count, and presents the 5-state bottom sheet.

### 3.3 5-State Verification Results
1. **Manufacturer-supported verification** (`VERIFIED` / Green): Batch number matches active manufacturer vault, expiration is in the future, serialized code aligns, and critical fields are confirmed.
2. **Reference information available** (`REFERENCE` / Blue): Drug matches approved regulatory registry, but batch is not registered in the manufacturer digital vault.
3. **Limited verification** (`LIMITED` / Neutral Slate): Partial packaging text read or critical fields unconfirmed by user.
4. **Suspicious indicators detected** (`SUSPICIOUS` / Warning Amber-Red): Expired medication, recalled batch, duplicate serialized scan anomaly (>5 scans across diverse locations), or counterfeit packaging anomalies.
5. **No reference information found** (`NO_REFERENCE` / Slate): No match in DRAP database or reference repository.

### 3.4 3-Field Audit Breakdown
Every verification result is transparently decomposed into:
- **Observed Data**: Exactly what was read from the physical image.
- **Reference Match**: Corresponding registry attributes matched in database.
- **Uncertainty**: Ambiguities, unread dates, unconfirmed tokens, or scan anomalies.

---

## 4. Prescription Extraction & Handwriting Reality

### 4.1 Printed vs. Cursive Handwriting
- **Current On-Device Model**: Powered by `google_mlkit_text_recognition`, which delivers robust offline Latin text recognition for printed clinic headers, printed discharge slips, digital prescriptions, and printed medicine packaging.
- **Doctor Cursive Script Reality**: Standard OCR engines struggle with extreme physician cursive handwriting. The architecture addresses this through:
  1. Clinical regex extraction isolating drug tokens from physician credentials and hospital boilerplate.
  2. Candidate matching against local reference brands and generic salts in `MedicineLookupRepository`.
  3. Safety fallback to `PrescriptionReviewScreen`, where unconfirmed items require explicit human review before scheduling medication alarms.

---

## 5. Security & Cloud Rules Architecture

### 5.1 Firestore Rules
- **No Self-Privilege Escalation**: Users cannot modify their own `role` or `permissions` fields on update or creation (`request.resource.data.role == resource.data.role`).
- **Verification Data Protection**: Public read access to verified medicine reference data; write access locked to authenticated `manufacturer` and `admin` roles.
- **Incident Reports**: Users can write incident reports (`anomalies`); reads restricted to manufacturer and regulatory admins.

### 5.2 Storage Security
- Default deny (`allow read, write: if false;`).
- Prescription and packaging scans strictly scoped to authenticated owners (`/users/{uid}/...`).
