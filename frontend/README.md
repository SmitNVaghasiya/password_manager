# PassMgr

Local-only encrypted password manager for Android. Built for personal use — no cloud, no accounts, no analytics.

> Personal use only. Not for Play Store. Not for public distribution.

---

## What it does

- Stores passwords encrypted with AES-GCM-256 on-device
- Master password + optional fingerprint unlock
- Auto-locks when app goes to background
- Password generator with length and character class controls
- Copy username/password to clipboard — auto-clears after 20 seconds
- Password history — every edit archives the old password (also encrypted)
- Encrypted backup export and import (`.enc` file via share sheet)
- Import passwords from Chrome CSV export — duplicate detection, "Already exists" badge, pre-unchecked duplicates
- Screenshots blocked (FLAG_SECURE)

---

## Screens

| Screen | Purpose |
|---|---|
| Setup | First launch — create master password + recovery hint |
| Lock | Unlock with master password or fingerprint |
| Vault | Searchable list of all saved passwords |
| Entry detail | View fields, copy with auto-clear, password history accordion |
| Add / Edit | Form with inline password generator |
| Settings | Auto-lock timer, biometric toggle, change master password, backup |
| Chrome import | Pick CSV, review each entry one by one, Skip or Add |

---

## Security

| Concern | Implementation |
|---|---|
| Encryption | AES-GCM-256 (`cryptography` package) |
| Key derivation | PBKDF2-HMAC-SHA256, 150,000 iterations, 32-byte random salt |
| Nonce | 12 bytes, fresh random per encryption — never reused |
| Key storage | In-memory only (`VaultSession`). Dropped on lock. |
| Biometric key | Stored in `flutter_secure_storage` (Android Keystore-backed) |
| Master password | Never stored. Verified by decrypting a known string. |
| Recovery | Hint only — not the password. No recovery if hint fails. |
| Screenshots | `FLAG_SECURE` via `secure_application` package |
| Android backup | `allowBackup=false` — prevents system backup exposing DB |
| Clipboard | Auto-cleared 20s after any copy action |

---

## Stack

| Concern | Package |
|---|---|
| Database | `sqflite` |
| Secure storage | `flutter_secure_storage` |
| Encryption | `cryptography` |
| Biometrics | `local_auth` |
| File picker | `file_picker` |
| CSV parsing | `csv` |
| Screenshot block | `secure_application` |
| Backup share | `share_plus` |

**Android minSdkVersion: 23** (Android 6.0+)

---

## Getting started

```bash
cd frontend
flutter pub get
flutter test          # run encryption roundtrip tests
flutter run           # connect Android device first
```

**IBM Plex Mono fonts** (for password display):
1. Download from [Google Fonts — IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono)
2. Place `IBMPlexMono-Regular.ttf` and `IBMPlexMono-Medium.ttf` in `frontend/fonts/`

---

## Data model

Three SQLite tables: `passwords`, `password_history`, `app_meta`.

`app_meta` keys: `kdf_salt`, `verifier_ciphertext`, `verifier_nonce`, `verifier_mac`, `recovery_hint`, `auto_lock_minutes`

---

## Honest scope warning

Do not put this on the Play Store. Do not give it to strangers.
Bitwarden is free, unlimited, and audited. This app exists because a simpler app that gets used beats a powerful app that doesn't.
