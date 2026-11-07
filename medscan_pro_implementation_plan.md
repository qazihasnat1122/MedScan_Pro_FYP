# MedScan Pro — Prioritized Implementation Plan

**Date:** 2026-10-22  
**Architecture Version:** Phase 10 Production Standard  

---

## Priority 1: Baseline Stability, Android Studio IDE & Build Pipeline (COMPLETED)
- [x] Configure multi-module IDEA project structure in `.idea/modules.xml` (root & nested).
- [x] Create shared `.idea/runConfigurations/medscan_mobile.xml` targeting `lib/main.dart` with `method v="2"`.
- [x] Ensure Android Studio recognizes `medscan_mobile` as the primary Flutter module.
- [x] Verify Android toolchain (`flutter doctor -v`, Android SDK 36.1.0, JDK 21).
- [x] Verify debug APK compilation (`flutter build apk --debug` - 44.4s).

---

## Priority 2: Deep Teal Design System & UI/UX Polish (COMPLETED)
- [x] Standardize theme tokens in `theme_constants.dart` (`MedScanTheme`) & `app_colors.dart`:
  - Canvas Background: `#071417`
  - Surface: `#0D2023`
  - Secondary Surface Container: `#12292D`
  - Primary Brand Teal: `#087F8C`
  - Mint Accent: `#16B8A6`
  - Main Text: `#F4FAFA`
  - Secondary Text: `#A8BEC1`
- [x] Fix greeting logic in `home_screen.dart` to prevent broken names ("Welcome Back, a").
- [x] Remove duplicate actions and oversized cards; streamline clinical action grid.
- [x] Harmonize bottom navigation bar and scan FAB with `AppColors.primary` and safe-area hit testing.
- [x] Standardize settings in `profile_screen.dart` with compact `CupertinoSlidingSegmentedControl`.
- [x] Fix price-check button label to "Check Price" and eliminate text truncation on `same_salt_finder_screen.dart`.

---

## Priority 3: Single-Photo Medicine Scanner & Truthful Verification (COMPLETED)
- [x] Implement frictionless single-viewfinder camera in `smart_scanner_screen.dart` via `mobile_scanner`.
- [x] Live Barcode/DataMatrix detection with haptic feedback.
- [x] Extract 6 attributes (brand, salt, strength, batch, expiry, form) from 1 photo.
- [x] Safety prompt for missing batch/expiry ("Batch/expiry not clearly visible — add one more photo?").
- [x] Enforce the 5 Section 8 project verification states without fabrication:
  1. `MANUFACTURER_SUPPORTED`
  2. `REFERENCE_AVAILABLE`
  3. `LIMITED_VERIFICATION`
  4. `SUSPICIOUS_DETECTED`
  5. `NO_REFERENCE_FOUND`
- [x] Provide 3-field audit breakdown (Observed, Reference, Uncertainty) in verification bottom sheet.
- [x] Scan anomaly and duplicate detection (> 2 scans flagged; > 5 scans critical).
- [x] 1-Tap "Report Suspicious Medicine" integration.

---

## Priority 4: Advanced Prescription Reading & Schedule Generator (COMPLETED)
- [x] Implement `PrescriptionParser` with noise filtering (doctor credentials, hospital headers, addresses, phones).
- [x] Structured JSON schema extraction (`medicine_name`, `strength`, `dosage_form`, `frequency`, `timing`, `duration_days`).
- [x] Medical safety: Eliminate fake sample injection on empty OCR. Return empty list `[]`.
- [x] Interactive `prescription_review_screen.dart` with Material 3 editable cards and modal editor.
- [x] Human-in-the-loop review confirmation gate for unconfirmed items.
- [x] Clean, informative empty state when OCR cannot detect structured items.
- [x] 1-Tap "Save to My Schedule" directly batch-saving to Firestore and scheduling local alarms.

---

## Priority 5: Real Data Integrity & Charting (COMPLETED)
- [x] Eliminate hardcoded dummy data from `GraphifyAdherenceChart`.
- [x] Render authentic empty state ("No Dose History Yet") when user has 0 scheduled medications.
- [x] Pass real medication list context from `home_screen.dart`.

---

## Priority 6: Firebase Security Hardening (COMPLETED)
- [x] Patch role privilege escalation vulnerability in `firestore.rules` for `users/{uid}`.
- [x] Lock down write access to `verificationData`, `scanActivity`, and `anomalies`.
- [x] Remove insecure catch-all in `storage.rules`, enforcing default-deny for unmapped paths.

---

## Priority 7: Testing & Verification (COMPLETED)
- [x] Static analysis: `flutter analyze --no-fatal-infos` (0 issues).
- [x] Mobile tests: `flutter test` in `medscan_mobile` (25/25 passing).
- [x] Web tests: `flutter test` in `medscan_web` (10/10 passing).
- [x] Knowledge graph synchronization: `graphify update .` (2,726 nodes, 3,788 edges, 179 communities).
