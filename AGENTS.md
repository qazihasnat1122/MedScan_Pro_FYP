# MedScan Pro — Agent Development Guidelines & Ponytail Standards

This document establishes the persistent engineering principles, quality baselines, and safety rules for all agentic development in the **MedScan Pro** project. All agents working in this repository must adhere to these instructions.

---

## 1. General Development Principles (Ponytail Core)

- **Simplest Complete Solution**: Always prefer the simplest complete solution. Write clean, direct, and production-conscious code.
- **The Ladder (Reflexive Reuse)**:
  1. *Does this need to exist at all?* Speculative needs are skipped (YAGNI).
  2. *Already in this codebase?* Inspect existing services, utilities, and widgets before writing new code.
  3. *Dart/Flutter Stdlib or Native feature?* Use standard library / framework primitives before custom logic.
  4. *Already-installed package covers it?* Reuse dependencies already declared in `pubspec.yaml`. Never add unnecessary dependencies.
  5. *Smallest safe implementation*: Favor minimal working diffs over boilerplate.
- **No Unrequested Abstractions**: Avoid unnecessary layers, interfaces with single implementations, singleton wrappers without state, and speculative scaffolding.
- **No Duplicate Functionality**: Do not duplicate existing code, helpers, or services.
- **Root-Cause Fixes**: Fix the root cause in the shared origin rather than applying band-aid patches across individual callers.
- **Preserve Working Modules**: Do not rewrite or refactor functioning modules without an explicit requirement and explanation.
- **No Sacrificing Safety or Completeness**: Never cut security, validation, error handling, or medical accuracy to reduce lines of code.

---

## 2. Ponytail Development Modes

Ponytail operates across distinct intensity levels:

- **LITE**: For small changes, simple bug fixes, and minor UI updates. Build requested change cleanly, highlighting simpler stdlib/native alternatives if appropriate.
- **FULL (DEFAULT)**: The default standard for MedScan Pro development, feature implementation, integrations, and ongoing maintenance. Enforces the Ladder, code reuse, minimal diffs, and concise explanations.
- **ULTRA**: For major code audits, architecture cleanups, and deep technical debt investigations (YAGNI extremist, deletion prioritized).
- **OFF**: Active only when explicitly requested by the user for a prompt or session.

*Default Mode for this project:* **FULL**.

---

## 3. Ponytail Skills & Automatic Selection

The following Ponytail skills are installed in the user's environment and available to the agent:

| Skill | Trigger / When to Apply |
|---|---|
| `ponytail` | Normal development, feature creation, bug-fixing, refactoring, and code generation adhering to Ponytail's ladder. |
| `ponytail-help` | Explaining Ponytail commands, configuration, principles, or usage. |
| `ponytail-review` | Conducting code reviews focused on eliminating over-engineering, dead code, and unnecessary abstractions. |
| `ponytail-audit` | Performing a repository-wide or module-wide scan for complexity, bloat, or redundant packages. |
| `ponytail-debt` | Cataloging deferred tasks and inspecting `ponytail:` comment markers across the codebase. |
| `ponytail-gain` | Demonstrating or reporting benchmark savings (code reduction, performance). |
| `ponytail-update` | Checking, updating, or syncing the locally installed Ponytail skill suite. |

*Agent Selection Rule:* Select only the relevant skill(s) required for the task. Do not execute or cite skills that were not invoked or relevant.

---

## 4. MedScan Pro Domain-Specific Rules

### 4.1 Medical Safety & Integrity
- **Zero Medical Hallucination**: Never invent or approximate medicine information, indications, interactions, dosages, or medical facts.
- **Strict Verification**: Never weaken medicine verification, OCR confidence thresholds, recognition checks, batch number verification, or expiry date parsing.
- **Prescription Privacy**: Maintain strict patient and prescription confidentiality; prevent logging of sensitive health data (PHI).
- **Clinical Nuance**: Never present differential possibilities or potential matches as definitive clinical diagnoses.
- **Safety Disclaimers & Emergency Warnings**: Always preserve emergency warnings, Poison Control / urgent care guidance, and disclaimer banners. Never eliminate these to save lines of code.

### 4.2 Firebase & Cloud Security
- **Credential Protection**: Never hardcode or expose API keys, Firebase secrets, private tokens, or sensitive configuration files.
- **Authentication & Security Rules**: Strictly maintain Firebase Auth token checks, user ownership scopes, and Firestore security rules (`firestore.rules`).
- **No Unnecessary External Services**: Do not introduce external third-party paid APIs, Cloudinary, or unapproved media brokers without explicit direction. Use configured Firebase Storage and Cloud Functions.

### 4.3 Offline-First Resilience
- Maintain local caching, offline sync mechanisms, and local SQLite/Hive/shared preferences where established.
- Avoid introducing blocking network calls where cached or offline flows are expected.

### 4.4 Flutter & Dart Standards
- **Widget & State Reuse**: Reuse existing custom widgets (`medscan_mobile/lib/widgets/` or shared components) and follow the project's established state management pattern.
- **Resource Lifecycle**: Always clean up and dispose `TextEditingController`, `AnimationController`, streams, and listeners.
- **Performance**: Avoid unnecessary widget rebuilds; use `const` constructors where applicable.
- **Layouts & States**: Consistently handle `Loading`, `Error`, `Empty`, and `Success` UI states with responsive layouts.

---

## 5. Safe Change Policy

### Before Modifying Code:
1. **Trace & Inspect**: Read and inspect relevant code files and their callers before changing them.
2. **Identify Root Cause**: Understand the true root issue rather than addressing superficial symptoms.
3. **Choose Minimal Safe Path**: Select the lowest-risk, smallest complete implementation that satisfies requirements.
4. **Audit for Reuse**: Verify if existing utilities, models, or widgets can fulfill the requirement.

### During Implementation:
1. **Targeted Diffs**: Touch only necessary files; avoid incidental formatting rewrites or unrelated refactoring.
2. **Preserve Compatibility**: Keep existing Firebase data schemas, models, and public APIs intact.
3. **Transparency**: For breaking or architectural alterations, outline impact clearly before executing destructive changes.

---

## 6. Testing & Verification Standard

After code edits:
- Run `flutter analyze` on affected Flutter packages (`MedScanPro/MedScanPro/medscan_mobile` or `medscan_web`).
- Run relevant unit or widget tests (`flutter test`) when applicable.
- Verify compilation and analyze diagnostics honestly.
- **Evidence-Based Reporting**: Explicitly distinguish between tests that were actually executed and components that were merely visually or statically inspected. Never claim code was verified without tool-backed execution.

---

## 7. Response Format for Development Tasks

When completing development tasks, structure the conclusion as follows:
1. **What was changed**: Summary of concrete changes.
2. **Why the change was necessary**: Context and problem solved.
3. **Files modified or created**: Explicit file list with links.
4. **Existing code reused**: Helpers, services, or widgets leveraged.
5. **Dependencies added**: Any additions to `pubspec.yaml` (justified or "None").
6. **Tests and verification performed**: Real command runs and outcomes.
7. **Remaining issues or limitations**: Known caveats or future follow-ups.
