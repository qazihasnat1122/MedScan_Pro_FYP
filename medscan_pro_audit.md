# MedScan Pro — Independent Re-Audit (verification of the previous audit report)

**Date:** 2026-10-22
**Scope:** Verify the earlier report ("20/20 PASS, ready for demo") against repository evidence; fix only confirmed high-priority defects.
**Labels:** **[V]** verified fact (command run / file read in this session) · **[I]** code-based inference · **[M]** outstanding manual check.

---

## 0. Limits of this audit (read first)

- **[V] No git repository exists** at any level of `D:\user\StudioProjects\MedScanPro` (`git status` → "not a git repository"). A diff of the previous audit's changes could not be produced; claims were checked by reading the current files directly. Recommend `git init` + commit before any further work.
- **[V] No physical-device, emulator-run, or live-Firebase testing was performed** in this audit or (per available evidence) the previous one. All "PASS" here means automated host tests + static review only.
- **[V]** Firestore rules were **edited locally only**; nothing was deployed. The rules were **not executed** against the Firebase emulator, so rule changes are **not test-verified** **[M]**.

---

## 1. Corrections to the previous report (claims that were wrong or overstated)

| Previous claim | Finding |
|---|---|
| "20/20 PASS" | **Not supported.** Several modules have no behavioral evidence or contradict their description (see `medscan_pro_module_status.md`). |
| `VerificationEngine` grants green only with a real manufacturer vault record | **False in the shipped code.** Offline/fallback lookup (`medicine_lookup_repository.dart`) returns **3 hardcoded sample batches compiled into the APK**; a name+batch match against them produced MANUFACTURER_SUPPORTED (green). Also, when no barcode was scanned, a batch-number text match alone set `batchVerified = true`. **Fixed (see §3).** |
| Pharmacy directory has "official DRAP retail license numbers" and location behaviour | **False.** 10 hardcoded entries; licence numbers (`DRAP-RET-…`) are **unverified and likely fabricated**; `isDrapLicensed: true` is hard-coded; distances (`approximateDistanceKm`) are fixed constants; **no location package or permission code exists** (no geolocator in `pubspec.yaml`). The example licence number in the old audit (`DRAP-RET-ISB-2024-0891`) does not exist in the repo. |
| Prescription UI shows "Camera OCR is optimized for printed clinic scripts" | **No such text exists.** Only the empty-state text mentions handwriting. Review gating exists but there is no explicit printed-vs-handwritten disclaimer on the normal review path **[M]/not fixed**. |
| Adherence fixed (no fake data) | **Incomplete.** `my_medicines_screen.dart` still rendered `GraphifyAdherenceMiniChart(weeklyRate: 0.94, streakDays: 7)` for every user. **Fixed.** |
| `ai_chat_pharmacist_test.dart` "verified clinical reasoning" | **Misleading.** The test exercised a function **defined inside the test file**, not `AiRagService`. **Replaced** with tests on the real service. |
| Emergency profile rule hardened | **Partly.** `read` with `isSharingEnabled == true` allowed **unauthenticated list/enumeration** of all shared profiles. **Fixed** (get vs list split). |
| "Manufacturer tenant isolation verified" | **Only client-side/in-memory.** Web tests use an in-memory store (Firebase not initialised in tests). Rules: any `manufacturer` could create catalog docs for another `manufacturerId`; web streams all `scanEvents`/`batches` and filters client-side. Partly fixed; remainder open (see §4). |

---

## 2. Verified results (commands actually run this session)

| Command (directory) | Result |
|---|---|
| `flutter pub get` (mobile) | exit 0 |
| `flutter analyze --no-fatal-infos` (mobile), baseline | exit 0, "No issues found" |
| `flutter test` (mobile), baseline | exit 0, **39/39** passed |
| `flutter analyze --no-fatal-infos` (mobile), after fixes | first run: **1 warning** (unused import I introduced) → fixed → second run exit 0, "No issues found" |
| `flutter test` (mobile), after fixes | exit 0, **42/42** passed |
| `flutter test` (web) | exit 0, **10/10** passed |
| `flutter analyze --no-fatal-infos` (web) | 33 *info* deprecation notices (`withOpacity`), 0 errors/warnings. (Exit code shown was of a piped command, so treat it as informational.) |
| `flutter build apk --release` (mobile), after fixes | exit 0, `app-release.apk` **117,466,490 bytes (≈112 MB)**, written 2026-10-22 15:34:40 |
| `flutter build web --release` (web) | exit 0, `build\web` built (56.5 s compile); not served or browsed |

Test counts: 49 reported earlier was **accurate for that moment** (39+10). Now 52 (42+10).

---

## 3. Defects fixed in this session

| # | Severity | Defect | Fix | Verification |
|---|---|---|---|---|
| F1 | HIGH | Green "Manufacturer-supported" reachable from sample data bundled in the APK | `MedicineLookupRepository.isBundledSampleBatch()`; `VerificationEngine` forces `batchVerified=false` + adds uncertainty for such records | Updated `real_scan_verification_test` (asserts never green); `verification_and_hologram_test` uses a non-bundled id to keep the live-vault green path covered. Tests pass. |
| F2 | HIGH | AI assistant: no disclaimer on local answers; default answer fabricated "evidence-based clinical guidance" for any question; "Verified against your active regimen" wording; counterfeit tips claimed "blockchain ledger" and "genuine boxes feature hologram" | Disclaimer appended to **every** answer (local and Gemini); default answer says it does not know and will not guess; wording corrected; packaging tips say a scan cannot prove authenticity; Gemini prompt told not to guess | 5 new tests on real `AiRagService` offline path; pass |
| F3 | HIGH | Interaction checker returned only specific warnings; no statement that absence ≠ safe | Always appends a limited-coverage notice when ≥2 medicines are screened | New test; pass |
| F4 | HIGH | Fake 94% adherence / 7-day streak on My Medicines | Widget removed; orphan import removed | Analyze clean |
| F5 | HIGH | Pharmacy screen claimed "verified DRAP-licensed", fixed fake distances | Labels changed to "sample directory / unverified"; distance replaced by "Distance n/a"; home tile subtitle corrected | Existing pharmacy tests pass; UI **not visually checked** **[M]** |
| F6 | HIGH | Firestore: unauthenticated enumeration of shared emergency profiles; forged `verificationRecords.userId`; any manufacturer could create catalog docs for other tenants; any manufacturer could create/alter/delete public safety **alerts** | `get`/`list` split; create requires `userId == auth.uid`; catalog create requires `manufacturerId == auth.uid` (or admin); alerts write = admin only (no client publishes alerts — verified by grep) | **Not tested** with emulator **[M]** |

An intermediate scripted edit corrupted `ai_rag_service.dart`; the file was restored by full rewrite from the previously read content with only the intended changes. Final analyze/test/build were run after the restore.

---

## 4. Open findings (not fixed — need design decisions)

1. **[V] Firestore tenant isolation is not enforced server-side for scans/anomalies:** `scanEvents`, `anomalies`, `suspiciousReports`, `scanActivity`, `verificationData` are readable by **any signed-in user, including anonymous/guest accounts**. Mobile needs `scanEvents` queries for duplicate counting, so tightening requires a Cloud Function/counter design.
2. **[V] Manufacturer role provisioning & `anomalies` updates:** web updates anomaly status from the client but rules allow update to admin only — likely failing for manufacturers **[I]**.
3. **[V] Web "DRAP/FBR verification" is a local static directory** (`drap_fbr_directory.dart`); login pre-fills `DRAP-MFG-00109`. Public page text says "centralized registry maintained by DRAP" — not true of this implementation.
4. **[V] Reference prices/medicines/batches are bundled static data** (e.g. Dianic bundled price 435 while the scanned pack shows 417). Price check is not live MRP/DRAP data.
5. **[V] DRAP recalls = Firestore `alerts` collection** (admin-written); no DRAP feed, no timestamp/staleness UI verified.
6. **[V] Scan location is a hardcoded string** ("Pakistan Mobile Device"); no GPS.
7. **[V] Gemini key is sent in the URL query string and patient medicines/allergies are sent to Google when a user supplies a key**; no explicit consent screen found **[M]**. Model `gemini-1.5-flash` may be retired **[M]**.
8. **[V] Interaction engine** substring-matches brand names against a 20-entry map and covers 3 pairs; allergy check covers only penicillin/amoxicillin; many interactions are absent (now explicitly disclosed).
9. **[V] Prescription OCR** uses ML Kit Latin printed-text OCR; handwriting is **not recognised**. Parser unit tests cover 4 cases only.
10. **[V] Seed sample pack carries "NOT FOR SALE / Punjab Govt Property"** text; nothing in the engine reacts to it.
11. **[V] Sample test fixtures use real brand/company names with invented licence numbers** (pharmacy directory) — replace with clearly fake names or real verified data.

---

## 5. Test-quality assessment

- 52 tests exist and ran. Mostly **pure-Dart unit tests**; mobile widget tests (3) use fakes/overrides. No integration tests, no Firebase emulator tests, **no rules tests**, no camera/OCR tests on real images (OCR parser is tested on one pasted OCR string).
- Web tests run against an **in-memory** store; "isolation" tests prove client filtering only.
- Passing tests do **not** prove clinical correctness.

---

## 6. Verdicts

### A. Controlled university demonstration — **YES, conditionally**
Conditions: (1) present as a **prototype using sample/seed data**; (2) do not say "genuine/verified by DRAP"; with seed data the app will now show *Reference available / Limited*, not green, unless real Firestore batch records are loaded; (3) do not demo handwriting recognition; (4) do not show the pharmacy list as verified.
Remaining actions before the demo:
1. Seed a Firestore emulator/test project with 1–2 manufacturer batch records via the web portal if a green state is wanted, and rehearse the flow **[M]**.
2. Run the release APK on at least one real Android device and rehearse scan, prescription and reminder flows **[M]**.
3. Visually check the changed screens (My Medicines, Pharmacies, AI chat) **[M]**.

### B. Public / commercial release — **NO**
Exact blockers:
1. Firestore rules not emulator-tested; open server-side isolation gaps (§4.1–4.2); no deployment/App Check verification.
2. No real data sources: DRAP registry, recalls, MRP, pharmacy licences are static/unverified.
3. No physical-device testing; no handwriting support; limited interaction database with no clinical review.
4. Medical-device/regulatory & privacy review (consent for sending health data to a third-party LLM, data retention) not done.
5. No version control, CI, or integration tests.

---
*Nothing was deployed, published or deleted. No external regulatory approval is claimed.*
