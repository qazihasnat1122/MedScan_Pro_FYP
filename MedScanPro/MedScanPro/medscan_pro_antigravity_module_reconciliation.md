# MedScan Pro — Module Reconciliation & Build Instructions for Antigravity
### Target Spec: Consolidated Mobile + Web Platform (October 2026)

---

## 0. READ THIS FIRST — WHAT TO DO WITH THIS DOCUMENT

This file contains the **target module specification** for MedScan Pro (Section 1
onward). Your job is NOT to build this from scratch — it is to:

1. **Inventory the current project** — read the existing codebase, existing
   design documents, and any previously-agreed architecture (symptom engine,
   Trust & Evidence Layer, Smart Action Hub, Family Health Control Center,
   Vaccination Tracker, Doctor Directory, Health Literacy Library, Chronic
   Disease Companion, Medication Safety Engine, CalmCare design system — these
   were designed in earlier project sessions and may or may not be reflected in
   the current codebase).
2. **Compare** that inventory against the target spec in this document, module
   by module.
3. **Produce a written reconciliation report** before changing any code (see
   §13) — do not silently add, remove, or restructure modules.
4. **Flag the scope conflict in §12** explicitly to the developer and wait for
   an answer before proceeding — do not resolve it yourself by guessing which
   set of modules is "correct."
5. Only after the developer confirms the reconciliation plan, modify the
   project to match.

This sequencing matters: this spec and the prior session's modules were
developed independently and were never explicitly merged. Silently picking one
over the other would throw away real design work on one side or the other.

---

## 1. Project Overview

MedScan Pro is a medicine-safety and verification-support platform for three
audiences: ordinary consumers, participating pharmaceutical manufacturers, and
authorized regulatory administrators. The mobile app focuses on camera-based
medicine checking and personal medication tools. The web platform provides
public medicine information plus separate, access-controlled workspaces for
manufacturers and administrators.

**Core principle (non-negotiable, applies to every module below):**
The system compares available information against trusted reference records and
surfaces useful signals. A database match or packaging-image match does not, by
itself, prove a physical medicine is genuine. When evidence is incomplete, the
system states that plainly instead of producing a fabricated positive result.
This is the same anti-fabrication discipline already established for this
project's symptom/medicine data — carry it forward consistently here.

---

## 2. Platform Split

| Platform | Primary audience | Main purpose |
|---|---|---|
| Flutter Mobile App | Consumers / patients | Camera scanning, personal medicine management, reminders, prescription support, interaction checking, emergency profile |
| Flutter Web — Public | Visitors / consumers | Medicine search, reference information, safety alerts, product explanation, mobile-app promotion |
| Flutter Web — Manufacturer Portal | Approved pharmaceutical organizations | Manage company medicines, batches, packaging references, and verification activity relevant to their products |
| Flutter Web — Regulatory Admin Portal | Authorized administrators | Manage reference data, manufacturer access, alerts, suspicious reports, and audit activity |

---

## 3. Flutter Mobile App — Modules & Full Functions

### 3.1 Account, Profile & Family Management
- Account creation, profile management.
- Optional family member linking via a **controlled invitation/linking
  process** (not raw ID entry — require explicit consent from the linked
  person, consistent with the Family Health Control Center design from the
  prior session, if that module is retained — see §12).
- Each person's private health data stays permission-protected; no implicit
  access just because two accounts are linked.

### 3.2 AI-Assisted Medicine Recognition & Camera Scanning
- User photographs packaging or a strip.
- OCR + barcode/QR reading + image processing extract: medicine name,
  strength, batch, expiry, and other visible details.
- **Uncertain readings must be surfaced for user confirmation** — never
  silently accepted. (Matches the OCR-confidence-threshold rule already
  established for prescription intelligence.)

### 3.3 Medicine Authenticity & Reference Verification
- Compares extracted info against general trusted reference records and,
  where available, manufacturer-supplied references/batch data/packaging
  images.
- Must use the cautious result-state vocabulary in §8 — never a binary
  genuine/fake output.

### 3.4 Trusted Medicine Information
- Shows brand/generic name, strength, dosage form, manufacturer,
  registration/reference identifiers (if available), storage info, and data
  source/status.
- Missing data is shown as missing — never fabricated or inferred.

### 3.5 Duplicate Identifier & Scan Anomaly Detection
- For genuinely unique serialized identifiers only: checks prior scans for
  unusual repetition or implausible patterns.
- A repeated QR/serial is a **warning signal, not proof** of counterfeiting.
- Location/time handling for this feature must be privacy-aware (minimum
  necessary data, not continuous tracking).

### 3.6 Prescription Capture & Medicine List
- Photo/upload of a prescription → OCR suggests medicine names and
  instructions.
- User must confirm extracted info before it's saved to their medication
  list — no auto-save of unconfirmed OCR output. (This is the existing
  Prescription Intelligence module from the prior session — reconcile, don't
  duplicate.)

### 3.7 Medicine Interaction Checker
- User adds medicines manually or from a confirmed prescription list.
- Checks against available interaction reference data; presents warnings in
  plain language.
- Always includes "consult a pharmacist or doctor for clinical decisions" —
  never positions itself as a clinical authority. (This is the existing
  Medication Safety Engine — reconcile, don't duplicate.)

### 3.8 Medicine Reminders & Medication Management
- Schedules, dose instructions, frequency, local notifications, medication
  history.
- Easy to edit manually.
- **The app must never independently change a prescribed dose or timing** —
  it only reflects what the user (or a confirmed prescription) specified.

### 3.9 Same-Salt Finder & Alternative Medicines
- Shows products sharing active ingredient, strength, and dosage form, when
  reliable data exists.
- Must explicitly state that matching ingredients does not guarantee a
  substitution is clinically suitable — always directs to a pharmacist/doctor
  for the actual substitution decision.

### 3.10 Price Check & Overcharge Indicator
- User enters/captures printed price and amount charged.
- Comparison only runs when a reliable, current reference price exists.
- Output is labeled as an **indication**, never a definitive legal finding.

### 3.11 Medicine Safety Alerts & Recalls
- Displays published alerts, recall notices, known batch warnings.
- Always shows source and date.
- Unverified user reports must never be presented as confirmed regulatory
  findings.

### 3.12 Suspicious Medicine Reporting
- User submits packaging photos, visible identifiers, purchase details,
  reason for concern.
- Reports are marked **unverified** until an authorized reviewer processes
  them (Admin Portal, §6.8).

### 3.13 Verification History & Shareable Report
- Shows previous scans and the information available at the time of
  checking.
- Must distinguish: observed data vs. reference match vs. unresolved
  uncertainty — three separate fields, not one blended summary.

### 3.14 Emergency Health Profile & QR
- Optional storage: allergies, current medicines, conditions, blood group (if
  known), emergency contact.
- QR exposes **only the selected information** via a controlled-access
  design — never the full medical record through an unrestricted static QR.
  (Matches the Emergency Mode/QR module from the prior session — reconcile.)

### 3.15 Nearby Pharmacy / Care Information (optional)
- Uses a legitimate location/map data source.
- Must clearly distinguish **directory information** from **verified live
  stock availability** — never claims a pharmacy has stock without live
  confirmation. (Matches the existing Healthcare Locator — reconcile.)

### 3.16 Language, Accessibility & Voice Support
- English and Urdu first; additional languages only as translations become
  available.
- Voice input/text-to-speech are optional enhancements, never required to
  complete a core task. (Matches existing Accessibility foundation —
  reconcile, don't duplicate.)

### 3.17 Notifications & Account Privacy
- Manage reminder notifications, safety-alert notifications, linked devices
  (if supported), consent settings, account deletion/data-access requests.
- Always ask permission before collecting optional sensitive information.

---

## 4. Flutter Web — Public Website — Modules & Full Functions

### 4.1 Public Landing Page
- Root route (`/`) is a polished public homepage — **not a login screen**.
- Introduces the platform, prominent medicine search, links to public info and
  organization portals.

### 4.2 Medicine Search
- Search by brand name, generic name, manufacturer, or reference number.
- Results come only from the actual database/repository.
- **An unknown search must never generate a fake "verified" medicine result.**

### 4.3 Public Medicine Catalogue & Details
- Lists available reference records.
- Detail page: concise medicine info, data source/status, relevant
  identifiers (if available), related safety alerts.

### 4.4 Verification Support Explanation
- Explains whether shown information is general reference data,
  manufacturer-supported data, or limited.
- Must never imply a text search alone proves a physical pack is genuine.

### 4.5 Published Safety Alerts
- Browsable alerts/recalls: medicine/batch, short reason, publication date,
  source/status.

### 4.6 How It Works
- Short explanation of searching, reviewing information, and using the mobile
  app for camera scanning and personal tools.

### 4.7 Mobile App Information
- Concise feature overview (scanning, reminders, prescription support,
  interaction checking, emergency profile) — promotional, not a recreation of
  the personal mobile dashboard.

### 4.8 Organization Portal Entry Points
- Clearly separated links: Manufacturer Login, Regulatory Admin Login.
- Entry points only — **a public visitor cannot switch into a protected
  portal by changing a visible role selector** (this must be enforced
  server-side, not just hidden in the UI — see §9).

### 4.9 About, Contact & Help
- Project info, contact/reporting guidance, privacy info, limitations.
- No unsupported claims of official government partnership or guaranteed
  counterfeit detection.

---

## 5. Flutter Web — Manufacturer Portal — Modules & Full Functions

### 5.1 Manufacturer Login & Access Request
- Approved org users sign in.
- New companies submit an access request that stays **pending** until
  reviewed.
- **Creating a Firebase account alone must never grant manufacturer access.**

### 5.2 Manufacturer Dashboard
- Genuine, database-backed counts: medicines, active batches, verification
  checks, open reports, recent activity.
- No invented integrity scores or fake metrics — "No data yet" when empty.

### 5.3 Company Medicine Management
- Create/view/update only the authenticated company's own medicine records
  and reference info.

### 5.4 Batch Management
- Batch number, linked medicine, manufacturing/expiry dates, status.
- Unit-level serialization is only described/shown when unique identifiers
  are actually generated and stored — never implied otherwise.

### 5.5 Packaging Reference Management
- Upload/maintain official reference images for relevant packaging
  sides/versions/medicines.
- Storage permission and image-size controls enforced.

### 5.6 Manufacturer Verification Data
- Maintains the company's approved medicine details, identifiers, and
  packaging/batch reference data used by the verification workflow (§3.3).

### 5.7 Company Verification Activity
- Review scans/checks associated with the company's products: result state,
  timestamp, anomaly flags — only where supported by actual recorded data.

### 5.8 Suspicious Reports
- Review reports relevant to the company's products.
- States: New / Under Review / Resolved.
- A manufacturer's own review **must never silently become a regulatory
  finding** — that authority stays with the Admin Portal (§6.8).

### 5.9 Safety Alerts
- View alerts relevant to company products.
- Publishing official/public alerts remains an Admin responsibility unless a
  separate, explicit permission is designed later.

### 5.10 Company Profile & Settings
- Maintain contact/account info.
- Changes to regulated identity or approval details require review — never
  auto-updates trusted status.

---

## 6. Flutter Web — Regulatory Admin Portal — Modules & Full Functions

### 6.1 Protected Admin Authentication
- **No public admin registration.**
- Admin accounts provisioned only through a controlled, server-authorized
  process.
- Admin role assignment must never be available from the Flutter client.

### 6.2 Regulatory Dashboard
- Real counts: manufacturers, medicine reference records, published alerts,
  verification activity, recent actions.
- Empty/unavailable metrics shown honestly, not hidden or faked.

### 6.3 General Medicine Reference Registry
- Manage general trusted reference records across participating and
  non-participating manufacturers, where reliable info is available.
- The presence of a record is **not proof** a scanned physical pack is
  genuine.

### 6.4 Manufacturer Directory
- Review company details, participation, approval status.
- States: Pending / Approved / Suspended.

### 6.5 Manufacturer Applications & Approvals
- Review submitted access requests and supporting info.
- Only an authorized backend/admin workflow grants manufacturer permissions
  and assigns a `manufacturerId` — never client-side.

### 6.6 Medicine / Reference Data Review
- Review submitted/updated manufacturer reference data.
- Maintain provenance, review status, timestamps.

### 6.7 Safety Alert & Recall Management
- Create / review / publish / update / retire alerts.
- Published alerts appear on the public website and can surface in the
  mobile app.

### 6.8 Suspicious Report Review
- Review user-submitted reports, add investigation status, record outcome.
- Must distinguish unverified reports from confirmed findings at every stage.

### 6.9 Verification Activity & Anomaly Monitoring
- Review recorded verification events and possible duplicate-identifier
  patterns.
- Anomaly flags are **investigative signals, not automatic proof** of
  counterfeit medicine.

### 6.10 User & Access Management
- Manage authorized accounts/status within defined permissions.
- Privileged roles granted server-side only — never self-selected.

### 6.11 Audit Logs
- Record administrative actions: actor, action, affected resource,
  timestamp, outcome.
- Do not claim cryptographic or government-grade audit infrastructure unless
  actually implemented.

---

## 7. Shared Backend & Technical Services

| Service | Role |
|---|---|
| Firebase Authentication | Account sign-in/identity. Consumer self-registration may be enabled; privileged roles are controlled separately (never self-assigned). |
| Cloud Firestore | Medicine references, manufacturer records, batches, packaging references, alerts, verification events, reports, private user data. |
| Firebase Storage | Packaging reference images, prescription images, report attachments — strict per-role/per-user access rules. |
| Cloud Functions / trusted backend | Server-side privileged actions: role assignment, approval workflows, anything that must never be trusted to the client. |
| Firebase Security Rules | Enforces data access at the backend. **Hiding a UI button or redirecting a route is not security** — rules are the actual boundary. |
| Notifications | Local medication reminders; safety notifications if implemented. |
| Search / OCR / image processing | Extracts candidate text/identifiers; recognition output must always be reviewable and never itself certifies authenticity. |
| Audit and monitoring | Records meaningful admin events/errors without logging unnecessary sensitive health data. |

---

## 8. Core Verification Result States (use these exact states everywhere verification appears — mobile, web, manufacturer, admin)

| State | Meaning shown to the user |
|---|---|
| Manufacturer-supported verification | Manufacturer-provided reference data available and scanned details match the supported checks. Still does not chemically prove contents. |
| Reference information available | A general reference record was found; manufacturer-supported verification may not be available. |
| Limited verification | Some information missing, unreadable, or not covered by available reference data. |
| Suspicious indicators detected | One or more mismatches, alerts, or unusual identifier patterns require caution/further review. |
| No reference found | No suitable record found. **This does not automatically mean counterfeit.** |

This vocabulary is consistent with (and should replace, if a conflicting
binary Authentic/Counterfeit result exists anywhere in the current codebase)
the evidence-based verification model from the prior session's audit.

---

## 9. Security & Role Rules

- **Consumer**: reads public medicine info and published alerts; accesses
  only their own private records.
- **Manufacturer**: must be approved; accesses only data tied to its assigned
  `manufacturerId`.
- **Admin**: no public registration; role granted only by a trusted,
  authorized process.
- **Never trust a client-supplied role value.** Use server-controlled custom
  claims or an equivalent secure authorization design, enforced by Firestore
  Security Rules.
- Never use permissive rules (`allow read, write: if true`) for private or
  privileged data.
- GoRouter guards improve navigation UX but **do not replace backend
  security** — every privileged read/write must also be enforced in Firestore
  rules / Cloud Functions, independent of what the client UI allows.
- Emergency QR access exposes only selected information, with a considered
  privacy/expiry/revocation design.
- Use consent, minimum-necessary-data principles, secure storage rules, and
  clear privacy notices for all health-related data.

---

## 10. UI / UX Standards

- Theme: dark premium medical-tech — deep teal surfaces, teal accents,
  readable light text, restrained status colors.
- Palette: background `#071417`, surface `#0D2023`, secondary surface
  `#12292D`, primary teal `#087F8C`, accent `#16B8A6`, primary text `#F4FAFA`,
  secondary text `#A8BEC1`.
- Plain English, short labels/descriptions, obvious primary actions,
  meaningful whitespace.
- Avoid: crowded dashboards, unnecessary cards, excessive glassmorphism,
  neon glow, floating 3D objects, long technical text.
- Every status uses icon + text, not color alone.
- Always provide loading / empty / error / success states; never show raw
  Firebase errors to users.
- Responsive across desktop, tablet, mobile browser sizes.
- Accessibility: adequate contrast, keyboard navigation, visible focus,
  readable type, practical touch targets.
- Only show live or calculated metrics; use "No data yet" or an em dash when
  unavailable — never a placeholder number that looks real.

> **Note for reconciliation (§12):** This palette is a dark teal medical-tech
> theme, distinct from the previously-established **CalmCare** design system
> (Deep Navy / Clinical Blue / Health Cyan light theme). These are two
> different visual identities for the same project — resolve which one is
> current before building UI, don't blend them ad hoc.

---

## 11. Implementation Priorities (as specified in the target spec)

```
Priority 1 — Foundation
  Audit existing code, confirm models/routes/providers, fix authentication
  and role security, remove fabricated verification fallbacks.

Priority 2 — Core verification
  Reliable medicine reference lookup, OCR confirmation flow, result states
  (§8), batch/identifier checks where available, reporting.

Priority 3 — Public Web
  Landing page, medicine search/details, safety alerts, how-it-works,
  organization portal entry points.

Priority 4 — Manufacturer Web
  Company medicine/batch/packaging reference management; verification
  activity; suspicious reports.

Priority 5 — Admin Web
  Reference registry, manufacturer approval, alerts, reports, activity,
  audit logs.

Priority 6 — Consumer Mobile
  Scanning, personal medicine list, prescription capture, interaction
  checker, reminders, alternatives, alerts, emergency profile.

Priority 7 — Quality assurance
  Test permissions, unknown-medicine behavior, empty data, loading/error
  states, responsiveness, accessibility, performance.
```

---

## 12. ⚠ SCOPE CONFLICT TO RESOLVE BEFORE BUILDING — DO NOT GUESS

This target spec (§1–11) and modules designed in a prior session for this same
project **do not fully overlap**. Specifically:

**Present in this spec, likely already partly built from the prior session
(reconcile, don't duplicate):**
Account/Family management (§3.1), Medicine scanning/OCR (§3.2–3.4),
Interaction checker (§3.7), Reminders (§3.8), Emergency profile/QR (§3.14),
Nearby pharmacy (§3.15), Accessibility (§3.16).

**Present in the prior session's design, ABSENT from this spec entirely —
status unclear:**
- Symptom Safety & Guidance Engine (offline symptom checker with emergency
  detection)
- Smart Action Hub (the "what do you want to do next" pattern after any scan)
- Family Health Control Center (roles: Caregiver/Viewer/Emergency-only,
  consent-based invite linking, audit log) — this spec's §3.1 is a much
  lighter version with no role model
- Vaccination & Child Health Tracker (EPI schedule)
- Chronic Disease Companion (vitals logging)
- Doctor & Specialist Directory
- Health Literacy Library
- MedBot (retrieval-only health assistant)
- CalmCare design system (light theme) — this spec specifies a dark teal
  theme instead

**Present in this spec, ABSENT from the prior session's design — genuinely
new:**
- The entire Manufacturer Portal (web)
- The entire Regulatory Admin Portal (web)
- Public Web platform (landing page, catalogue, public alerts)
- Duplicate identifier/serial anomaly detection
- Price check / overcharge indicator
- Same-salt alternative finder

**Before writing any code, ask the developer:**
1. Is this spec a **replacement** for the earlier consumer-health-companion
   direction (symptom engine, family control center, vaccination tracker,
   etc.), or is it meant to **sit alongside** it as an expanded platform?
2. If alongside: which design system is current — CalmCare (light) or this
   dark teal theme — and should the consumer modules from the prior session
   be folded into Section 3 of this spec using whichever modules don't
   conflict?
3. If this spec is the new priority: should the prior session's unique
   modules (Symptom Engine, Vaccination Tracker, Doctor Directory, Health
   Literacy Library, MedBot) be shelved, kept as a later-phase addition, or
   dropped entirely?

Do not resolve this by quietly merging everything or quietly discarding one
side — the scope difference (a B2C health companion vs. a three-sided
B2C/B2B/B2G verification platform) is large enough that guessing wrong wastes
significant work.

---

## 13. Reconciliation Workflow (follow in this order)

1. **Inventory**: list every module/screen/service that currently exists in
   the codebase (file-by-file if needed), and every design document from the
   prior session that's available to you.
2. **Map**: for each module in §3–§6 of this spec, mark it:
   `ALREADY BUILT (matches)` / `ALREADY BUILT (conflicts — needs
   modification)` / `NOT YET BUILT` / `BUILT BUT NOT IN THIS SPEC (prior
   session only)`.
3. **Report**: present this mapping to the developer as a table, plus the
   §12 questions, before writing or modifying any code.
4. **Wait for confirmation** on §12's three questions.
5. Only then: modify the project following the confirmed scope, in the
   priority order from §11 (adjusted if the developer's answer changes
   priority — e.g., if the consumer-health-companion modules are being kept,
   they likely belong in Priority 6 alongside the modules already listed
   there, not as a separate afterthought).
6. Apply the non-negotiable rules consistently across whichever final module
   set is confirmed: no fabricated verification results, no client-trusted
   roles, every uncertain extraction gets a human confirmation step, every
   verification output uses the §8 state vocabulary (or an equivalent
   evidence-based vocabulary if the symptom/disease side of the app is kept,
   matching its own previously-established Trust & Evidence Layer states).

---

## 14. Important Scope Notes (carried from the target spec, still apply)

- These modules define intended scope; they do not imply every feature is
  already implemented.
- AI/OCR should assist data extraction, never invent medicine facts or
  independently diagnose patients.
- Interaction/alternative modules depend on a reliable, reviewed
  drug-information dataset; if a check can't be completed, show that
  limitation clearly rather than guessing.
- Manufacturer partnerships may not exist for every company — support general
  reference records separately from manufacturer-supported ones.
- Duplicate serial detection requires genuinely unique identifiers and
  recorded scan history — a copied QR is only detectable as a duplicate when
  the system has sufficient scan history or another trusted check.
- Any DRAP integration, official approval, recall feed, map data, or
  real-time inventory must be described as integrated only after it is
  genuinely connected and tested — never described as live before that's
  true.
