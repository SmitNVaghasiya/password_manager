# PassMgr Full App — Design Spec
**Date:** 2026-05-19
**Author:** Smit Vaghasiya
**Status:** Approved — ready for implementation

---

## 1. Overview

Local-only Android password manager for two specific users (Smit + dad). No cloud, no accounts, no Play Store. Data lives in on-device SQLite encrypted with AES-GCM-256. App is a Flutter project located at `frontend/`.

---

## 2. Scope

All 18 files built sequentially, one at a time, in the order defined in Section 7. No files skipped.

### In scope
- Full encryption layer (AES-GCM-256, PBKDF2-HMAC-SHA256, 150k iterations)
- Master password setup + unlock flow
- Biometric unlock (fingerprint via `local_auth`)
- Auto-lock on background
- Vault list with search
- Add / Edit entry with inline password generator
- Entry detail with copy-with-auto-clear and password history
- Settings screen (auto-lock, change master password, biometric toggle, export, import)
- Chrome CSV import with per-entry confirm flow
- Encrypted backup export + import
- FLAG_SECURE (screenshot block)
- Clipboard auto-clear (20s)
- Delete with confirmation dialog
- Empty states

### Out of scope (v1)
- Cloud sync
- Categories / folders / tags
- TOTP / 2FA
- Browser autofill
- Dark mode toggle (follow system)
- Password strength meter
- Multi-vault / multi-user
- Play Store publishing

---

## 3. Architecture

### Layer structure
```
lib/
  main.dart               — routing gate + lifecycle observer
  theme/
    app_theme.dart        — colors, typography, ThemeData
  services/
    encryption_service.dart   — AES-GCM-256 + PBKDF2 + password generator
    database_service.dart     — SQLite CRUD + app_meta + history
    vault_session.dart        — in-memory key holder, lock/unlock, auto-lock timer
    biometric_service.dart    — local_auth + flutter_secure_storage
    backup_service.dart       — encrypted export + import
  screens/
    setup_screen.dart         — first-launch master password creation
    lock_screen.dart          — unlock: master password + biometric
    vault_screen.dart         — list + search + FAB + empty state
    entry_detail_screen.dart  — fields + copy + history dropdown
    edit_entry_screen.dart    — add/edit form + password generator widget
    settings_screen.dart      — auto-lock, change password, biometric, export, import
    chrome_import_screen.dart — CSV picker + per-entry confirm flow
  widgets/                    — shared widgets extracted as needed
```

### State management
`setState` + `ChangeNotifier`. No Provider, no Riverpod — app is small, do not over-engineer.

### Routing
Named routes via `MaterialApp.routes`. Boot sequence:
1. `main.dart` checks `app_meta` for `kdf_salt`
2. If absent → `/setup`
3. If present → `/lock`
4. Unlock success → `/vault`

---

## 4. Data Model

### Table: `passwords`
```sql
CREATE TABLE passwords (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  site_name             TEXT    NOT NULL,
  username              TEXT    NOT NULL,
  url                   TEXT,
  password_encrypted    BLOB    NOT NULL,
  password_nonce        BLOB    NOT NULL,
  password_mac          BLOB    NOT NULL,
  notes_encrypted       BLOB,
  notes_nonce           BLOB,
  notes_mac             BLOB,
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL
);
```

### Table: `password_history`
```sql
CREATE TABLE password_history (
  id                       INTEGER PRIMARY KEY AUTOINCREMENT,
  password_entry_id        INTEGER NOT NULL,
  old_password_encrypted   BLOB    NOT NULL,
  old_password_nonce       BLOB    NOT NULL,
  old_password_mac         BLOB    NOT NULL,
  changed_at               INTEGER NOT NULL,
  FOREIGN KEY (password_entry_id) REFERENCES passwords(id) ON DELETE CASCADE
);
```

### Table: `app_meta`
```sql
CREATE TABLE app_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

**Keys used:**
| Key | Value |
|---|---|
| `kdf_salt` | base64-encoded 32-byte random salt |
| `verifier_ciphertext` | base64 — `"VAULT_OK_v1"` encrypted at setup |
| `verifier_nonce` | base64 |
| `verifier_mac` | base64 |
| `recovery_hint` | plain text hint, never the password itself |
| `auto_lock_minutes` | `'1'`, `'5'`, or `'10'` |

---

## 5. Encryption Design

### Algorithm
- AES-GCM-256 via `cryptography` package
- Key derivation: PBKDF2-HMAC-SHA256, 150,000 iterations, 32-byte random salt
- Nonce: 12 bytes, fresh random per encryption — NEVER reused
- GCM MAC: 16 bytes, stored alongside ciphertext

### Setup flow
1. User enters master password (min 8 chars, confirmed twice)
2. Generate 32-byte random salt → store in `app_meta.kdf_salt`
3. Derive 32-byte key via PBKDF2
4. Encrypt `"VAULT_OK_v1"` → store ciphertext + nonce + MAC as verifier in `app_meta`
5. Store derived key in `flutter_secure_storage` gated by biometric
6. Collect recovery hint → store plain in `app_meta.recovery_hint`

### Unlock flow
1. Read salt + verifier from `app_meta`
2. Derive key from entered password + salt
3. Attempt to decrypt verifier
4. Success → hold key in `VaultSession` memory, navigate to `/vault`
5. Failure → return error, do not throw
6. Biometric path: read pre-stored key from `flutter_secure_storage` via `local_auth`, skip KDF

### Per-entry encryption
- `password` field: AES-GCM encrypt → store `password_encrypted` + `password_nonce` + `password_mac`
- `notes` field: same pattern, nullable
- Fresh nonce per save operation

### Lock
- Drop key reference from `VaultSession`
- Pop all routes to `/lock`

### Change master password
1. Verify old password → derive old key
2. Derive new key (new random salt)
3. Decrypt every entry + history + notes with old key
4. Re-encrypt all with new key inside single SQLite transaction
5. Update verifier with new key
6. Show progress indicator during re-encryption
7. Transaction rollback on any failure — no partial re-encryption

---

## 6. Screen Contracts

### `/setup` — SetupScreen
- Master password field (obscured) + confirm field
- Min 8 chars validation
- Recovery hint text field (optional but prompted)
- "Create Vault" button → runs setup flow → navigate to `/vault`

### `/lock` — LockScreen
- Master password field + "Unlock" button
- Biometric button (fingerprint icon) if biometric enrolled
- Show recovery hint link → reveal hint text
- Wrong password → inline error, no dialog
- On success → navigate to `/vault`

### `/vault` — VaultScreen
- Search bar (filters `site_name` + `username`, case-insensitive)
- List of `PasswordEntry` cards: site name + username + avatar initial
- FAB → `/edit` (new entry)
- Tap entry → `/detail`
- Empty state: "No passwords yet. Tap + to add your first."
- AppBar: "PassMgr" title + settings icon → `/settings`

### `/detail` — EntryDetailScreen
- Site name, username, URL (tappable), notes
- Password field (obscured by default) + eye toggle
- Copy buttons for username + password → toast "Copied — clears in 20s" + 20s clipboard clear timer
- Password history accordion: dates + old passwords (obscured, eye toggle per row)
- Edit FAB → `/edit` with entry
- Delete button → confirmation dialog → cascade delete

### `/edit` — EditEntryScreen
- Site name, username, URL, password, notes fields
- Password generator card: length slider (8–32), uppercase/lowercase/numbers/symbols toggles, "Generate" button
- Amber warning banner if editing existing: "Saving will move current password to History"
- Save → encrypt → DB insert/update → pop back

### `/settings` — SettingsScreen
- **Security:** auto-lock timer (1 / 5 / 10 min), biometric toggle, change master password
- **Data:** export encrypted backup, import backup
- **About:** app version
- Change password → verify old, enter new (min 8 chars), confirm → full re-encrypt flow with progress

### `/import` — ChromeImportScreen
- File picker for `.csv`
- Parse Chrome CSV format: `name, url, username, password, note`
- Per-entry confirm flow: show one entry at a time, Skip / Add buttons
- "Add all remaining" shortcut button
- Progress bar
- Summary on completion: X added, Y skipped

---

## 7. Build File Order

| # | File | Depends on |
|---|---|---|
| 1 | `pubspec.yaml` | — |
| 2 | `android/app/build.gradle.kts` | — |
| 3 | `android/app/src/main/AndroidManifest.xml` | — |
| 4 | `lib/theme/app_theme.dart` | — |
| 5 | `lib/services/encryption_service.dart` | — |
| 6 | `lib/services/database_service.dart` | encryption_service |
| 7 | `lib/services/vault_session.dart` | encryption_service, database_service |
| 8 | `lib/services/biometric_service.dart` | vault_session |
| 9 | `lib/services/backup_service.dart` | encryption_service, database_service |
| 10 | `lib/main.dart` | all services, app_theme |
| 11 | `lib/screens/setup_screen.dart` | vault_session, app_theme |
| 12 | `lib/screens/lock_screen.dart` | vault_session, biometric_service, app_theme |
| 13 | `lib/screens/vault_screen.dart` | database_service, vault_session, app_theme |
| 14 | `lib/screens/entry_detail_screen.dart` | database_service, vault_session, app_theme |
| 15 | `lib/screens/edit_entry_screen.dart` | database_service, vault_session, encryption_service, app_theme |
| 16 | `lib/screens/settings_screen.dart` | vault_session, biometric_service, backup_service, database_service, app_theme |
| 17 | `lib/screens/chrome_import_screen.dart` | database_service, vault_session, encryption_service, app_theme |
| 18 | `test/encryption_test.dart` | encryption_service |

---

## 8. Design Tokens

| Token | Value | Use |
|---|---|---|
| `paper` | `#F5F1EA` | App background |
| `ink` | `#0F1419` | Primary text |
| `inkSoft` | `#4A5159` | Secondary text |
| `inkMute` | `#8A8F97` | Placeholder, muted |
| `card` | `#FFFFFF` | Card backgrounds |
| `border` | `#E4DED2` | Hairline borders |
| `emerald` | `#1E5F4E` | Primary accent |
| `emeraldSoft` | `#E8F0EC` | Emerald tint |
| `amber` | `#B45309` | Warnings |
| `amberSoft` | `#FBF1E2` | Amber tint |
| `danger` | `#B91C1C` | Delete, errors |

**Fonts:** Inter (UI), IBM Plex Mono (passwords + secrets)
**Shape:** 16px card radius, 12px input radius, hairline borders, no heavy shadows

---

## 9. Security Requirements

- FLAG_SECURE enabled at all times — no screenshots, no recent-apps preview leak
- Clipboard auto-clear: 20 seconds after any copy action
- Biometric key stored in `flutter_secure_storage` (Android Keystore-backed)
- Key never written to disk unprotected
- Nonce never reused — fresh random per encryption call
- Delete confirm dialog — no single-tap delete
- Recovery hint stored plain — never store the actual password
- Master password change: single transaction, rollback on failure

---

## 10. Android Config

- `minSdkVersion`: 23 (Android 6.0) — required for fingerprint + Keystore
- `targetSdkVersion`: 34
- Permissions: `USE_BIOMETRIC`, `USE_FINGERPRINT`
- `android:allowBackup="false"` — prevent Android auto-backup exposing encrypted DB
- `android:fullBackupContent="false"`

---

## 11. Dependencies (pubspec.yaml)

```yaml
sqflite: ^2.3.3
path: ^1.9.0
cryptography: ^2.7.0
flutter_secure_storage: ^9.2.2
local_auth: ^2.3.0
file_picker: ^8.1.2
csv: ^6.0.0
secure_application: ^4.2.4
path_provider: ^2.1.3
share_plus: ^10.0.0
```

---

## 12. Test Coverage

`test/encryption_test.dart`:
- PBKDF2 deterministic output given same password + salt
- AES-GCM encrypt → decrypt roundtrip (50 iterations)
- Different nonces produced per call
- Wrong key fails decryption with exception, not silent corruption
- Password generator produces output within specified length + char constraints
