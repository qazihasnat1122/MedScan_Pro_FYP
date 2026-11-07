# MedScan Pro — Module Verification Status (independent re-audit)

**Date:** 2026-10-22
**Basis:** repository inspection + automated host tests (mobile 42/42, web 10/10) + static analysis. **No physical-device or emulator-run or live-Firebase evidence exists for any module.**

**Key:** PASS = meaningful behaviour covered by an executed automated test **and** no known contradicting defect · PARTIAL = implemented, only partly evidenced or with known limits · NOT VERIFIED = code exists, no executed evidence · FAIL = confirmed defect not fixable in scope · NOT IMPLEMENTED.
Test level: U = unit, W = widget (host, faked services), none = no test.

| # | Module | Status | Evidence / limitations |
|---|---|---|---|
| 1 | Account, profile & auth | **PARTIAL** | `widget_test.dart` (3 tests, U/W with overridden providers) covers routing for onboarding/auth/main only. Real Firebase Auth sign-in, guest sign-in, profile persistence **not tested**. |
| 2 | Medicine recognition / single smart capture | **PARTIAL** | `packaging_ocr_parser_test` (3) parses one pasted OCR string + empty/noise. Camera, ML Kit, barcode decode, confirmation screen: **not tested**. Printed OCR only. |
| 3 | Authenticity / reference verification | **PARTIAL** | `verification_*` tests cover green (simulated live record), expired→suspicious, and (new) bundled-sample cap. Not covered: no-reference, limited, anomaly thresholds, unconfirmed-field gate, barcode mismatch. **Match to text/barcode ≠ proof of genuineness**; green needs a live manufacturer record, which no shipped data provides. |
| 4 | Trusted medicine information | **PARTIAL** | Lookup test on bundled static list only; data is sample/static, not DRAP-sourced. |
| 5 | Duplicate-identifier anomaly | **NOT VERIFIED** | Logic in engine (`>5` suspicious, `>2` uncertainty) has no test; Firestore count query needs open `scanEvents` read (rules gap). |
| 6 | Prescription capture & review | **PARTIAL** | `prescription_parser_test` (4): blank, header noise, one valid line, name match. Printed-text only; **no handwriting recognition**; review gating untested at widget level; no explicit printed-vs-handwriting notice on normal path. |
| 7 | Interaction checker | **PARTIAL** | `clinical_service_test` (6): brand→salt, duplicate salt, 3 pairs, unmapped notice, single med, and (new) coverage notice. Tiny hand-written database, not clinically reviewed. AI chat now has universal disclaimer (5 tests on real service); Gemini path untested. |
| 8 | Reminders & adherence | **PARTIAL** | `dose_schedule_test` (3) tests time parsing/sorting/rollover helpers. Actual notification scheduling, exact-alarm permission, reboot behaviour **not tested**. Fake adherence widget removed; no real adherence data source exists. |
| 9 | Same-salt finder | **NOT VERIFIED** | No test; depends on bundled sample list (exact generic-name match). |
| 10 | Price check (MRP) | **PARTIAL** | No test. Reference prices are bundled static values (not live DRAP MRP). Disclaimer present in UI **[code-read]**. |
| 11 | Safety alerts / recalls | **PARTIAL** | Offline stream error handling added (untested). Source = Firestore `alerts` (admin-write). No DRAP feed, no freshness/timestamp verification. |
| 12 | Suspicious reporting | **NOT VERIFIED** | Code writes `suspiciousReports`; no test; any signed-in user can read all reports (rules gap). |
| 13 | Verification history / audit breakdown | **PARTIAL** | Model round-trip tests only; Observed/Reference/Uncertainty structure exists in engine; UI not tested. |
| 14 | Emergency profile & QR | **PARTIAL** | Model serialisation test only. Rules changed (no enumeration) — **not emulator-tested**. QR/consent flow not tested. |
| 15 | Nearby pharmacy directory | **PARTIAL (static sample)** | 5 tests on static list/filter/search. Data = 10 hard-coded entries with **unverified licence numbers**; **no location use, no permission handling, no network source**. UI relabelled "sample/unverified". Not "nearby", not "DRAP-licensed". |
| 16 | Language / accessibility | **PARTIAL** | `app_settings_test` (4): string presence, toggles. Urdu accuracy, RTL layout, text scaling **not tested** (previous claim of accessibility verification unsupported). |
| 17 | Notifications, consent & privacy | **PARTIAL** | No tests. Gemini key now empty by default; patient data sent to Google if user supplies a key, no consent screen found. Rules partly hardened, untested. |
| 18 | Public web platform | **PARTIAL** | `widget_test` ("App starts") + web build. Content is static/sample; page text overstates DRAP registry. |
| 19 | Manufacturer portal | **PARTIAL** | 9 tests on **in-memory** store; DRAP/FBR check is a **local static directory**; isolation proven client-side only; rules: create now owner-bound, but scan/anomaly data readable by all signed-in users. |
| 20 | Regulatory admin portal | **NOT VERIFIED** | Admin screens include placeholders (`AdminPlaceholderScreen`: alerts, settings); no tests for role gating; only rules enforce admin writes (untested). |

## Summary (honest)
- **PASS: 0 / 20** — no module has end-to-end/device/live-service evidence; several are host-tested logic only.
- **PARTIAL: 16** · **NOT VERIFIED: 4** (5, 9, 12, 20) · **FAIL: 0** · **NOT IMPLEMENTED: 0** (but 15 is a static sample, handwriting recognition is not implemented, and admin alerts/settings are placeholders).
- The previous "20/20 PASS" is **withdrawn**.
