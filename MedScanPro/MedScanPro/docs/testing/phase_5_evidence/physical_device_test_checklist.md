# Physical Android Device Test Protocol & Acceptance Checklist

**Document Date:** 2026-11-09  
**Execution Environment:** Windows workstation / ADB  
**Device Connection Status:** `adb devices` output:
```
List of devices attached
(No physical devices or emulators attached)
```
**Acceptance Status:** **NOT TESTED — No Physical Hardware Attached** (Zero fabrication per MedScan Pro standard)

---

## 1. Physical Device Verification Protocol

When a physical Android handset (e.g. Pixel, Samsung, or Xiaomi running Android 11+) is connected via USB debugging, execute the following standardized validation sequence:

| Step # | Test Workflow | Test Procedure | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|
| **P1** | **Camera Hardware Capture** | Tap "Take Photo", allow camera runtime permission, point at physical prescription, capture image. | Image viewfinder previews clearly; photo captures without crash; image compression reduces size < 350 KB; preview screen displays photo. | Device not connected | **NOT TESTED** |
| **P2** | **Gallery Image Selection** | Tap "Choose from Gallery", select saved JPEG/PNG prescription image from device storage. | File picker opens; image loads into previewer; dimensions and size displayed; pinch-to-zoom interactive. | Device not connected | **NOT TESTED** |
| **P3** | **Multi-Page PDF Import** | Tap "Upload PDF Document", select a 1–4 page prescription PDF via system file picker. | Native document picker opens; page count parsed; page navigation buttons enable browsing between pages; non-PDF rejected. | Device not connected | **NOT TESTED** |
| **P4** | **AI Consent Dialog** | Tap "Extract Prescription" button on imported document. | Privacy modal appears warning user of external AI processing; extraction proceeds only upon tapping "I Agree". | Verified in Widget Test | **PASS (Static/Widget)** / **NOT TESTED (Physical)** |
| **P5** | **Cloud Function / OCR Fallback** | Execute extraction on document. If Cloud Function is 404, tap "Try On-Device OCR". | Error surfaces gracefully; "Try On-Device OCR" extracts visible text via Google ML Kit Text Recognition; no crash occurs. | Verified in Unit Test | **PASS (Mocked)** / **NOT TESTED (Physical)** |
| **P6** | **Review & Correction UI** | Review extracted drug lines side-by-side with original prescription preview. | Unconfirmed items visually flagged; tapping "Edit" opens full modal; user can modify name, strength, frequency, timing, duration. | Verified in Widget Test | **PASS (Widget)** / **NOT TESTED (Physical)** |
| **P7** | **Anti-Fabrication Guard** | Confirm medicine with missing name. | SnackBar blocks confirmation: "Medicine name is missing. Please edit and enter the medicine name before confirming." | Verified in Unit Test | **PASS (Unit/Widget)** / **NOT TESTED (Physical)** |
| **P8** | **Prescription History Save** | Tap "Save to Prescription History". | Record saved to Firestore under authenticated user's UID; session ID prevents duplicate entries on double tap; success toast displayed. | Verified in Unit Test | **PASS (Unit/Repo)** / **NOT TESTED (Physical)** |
| **P9** | **Records Screen & Deletion** | Navigate to Records -> "Prescriptions" tab. | Saved prescription appears in list; expandable tile shows medicines; "Delete Record" and "Delete Stored File" function correctly. | Verified in Code Audit | **PASS (Code Audit)** / **NOT TESTED (Physical)** |
| **P10** | **Medicine Reminder Setup** | Tap "Schedule Reminders" from review screen. | Modal pre-fills medicine name and frequency; PRN/tapering defaults disabled; user explicitly picks clock times; permission prompt handled. | Verified in Unit Test | **PASS (Unit/Widget)** / **NOT TESTED (Physical)** |
| **P11** | **Physical Alarm Notification** | Set reminder clock time for +2 minutes from current wall clock time. | System alarm fires notification banner with medicine name and dosage instructions at scheduled minute; tapping opens app. | Device not connected | **NOT TESTED** |

---

## 2. Summary of Automated vs Physical Test Coverage

- **Automated Unit & Widget Tests Executed:** 13/13 PASSED
- **Backend Contract Tests Executed:** 5/5 PASSED
- **Static Code Analysis Diagnostics:** 0 issues
- **Physical Device Tests Executed:** 0 (Blocked on USB hardware connection)
