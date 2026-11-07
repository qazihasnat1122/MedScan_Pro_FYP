# MedScan Pro Ponytail Development Standard

This rule enforces Ponytail development principles, quality standards, and medical domain safety checks across all coding tasks in MedScan Pro.

## Core Rules
- **Reference**: Follow all standards codified in [AGENTS.md](file:///d:/user/StudioProjects/MedScanPro/AGENTS.md).
- **Default Mode**: **FULL** (Lite for minor fixes, Ultra for codebase audits / debt reduction).
- **The Ladder**: Check whether code is needed (YAGNI) -> Reuse existing in codebase -> Stdlib/Native -> Existing dependencies -> Minimal safe diff.
- **Medical Safety**: Never hallucinate medical info, weaken verification, or remove safety disclaimers/emergency warnings.
- **Firebase & Security**: Never expose secrets, bypass Firestore rules, or introduce unapproved external paid APIs.
- **Reporting**: Follow the structured 7-point delivery format defined in AGENTS.md on completion.
