# MedScan Pro FYP — Git Security & Excluded Files Policy

This document details the sensitive files, private credentials, and machine-specific configurations explicitly excluded from Git version control via `.gitignore`.

---

## Excluded Files and Folders

| File / Folder | Reason |
|---|---|
| `.env` | Contains private API keys |
| `.env.local` | May contain private credentials |
| `local.properties` | Local Android SDK path |
| `key.properties` | Android signing credentials |
| `*.jks / *.keystore` | App signing private keys |
| `google-services-adminsdk*.json` | Firebase Admin credentials |
| `serviceAccountKey.json` | Firebase Admin private key |
| `*.pem / *.p12` | Private certificates and keys |
| `functions/.env` | Cloud Functions secrets |
| `functions/.env.*` | Cloud Functions environment secrets |

---

## Why These Files Are Excluded

1. **Patient & API Privacy:** Files such as `.env` and `functions/.env` contain live developer API keys (Google Gemini, Cloud Function endpoints, Mapbox). Committing them to a public repository risks quota exhaustion, billing abuse, and automatic revocation by GitHub Secret Scanning.
2. **Platform & Build Portability:** `local.properties` hardcodes local machine paths to the Android SDK (`sdk.dir`) and Flutter SDK (`flutter.sdk`), which differ across developer machines and break Gradle builds on other computers.
3. **Cryptographic Signing Protection:** Private keystores (`*.jks`, `*.keystore`, `key.properties`) and certificates (`*.pem`, `*.p12`) are used to sign production Android APKs and must never be exposed publicly.
4. **Firebase Administrative Scopes:** `serviceAccountKey.json` and `google-services-adminsdk*.json` grant root administrative bypass permissions over Firestore and Firebase Auth and are prohibited in client source control.

---

## Collaborator Setup (Zero Configuration)

MedScan Pro is configured so collaborators can clone, build, and run without any of the above private files:
- Standard Firebase client configuration is safely managed via `google-services.json` and `firebase_options.dart`.
- Public Mapbox discovery is pre-configured with a public client token (`pk.*`).
- Medical scanning and DRAP catalog matching operate 100% on-device via ML Kit.
- Health chat operates offline via the built-in clinical reasoning engine without requiring a cloud API key.
