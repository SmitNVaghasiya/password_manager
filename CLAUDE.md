# CLAUDE.md — PassMgr Project Context

**Last updated:** 2026-05-19
**Owner:** Smit Vaghasiya (`smitvaghasiya11280@gmail.com`)
**App:** PassMgr — local-only Android password manager
**Stack:** Flutter · SQLite (`sqflite`) · `cryptography` (AES-GCM-256) · `local_auth` · `flutter_secure_storage`
**Platforms:** Android only (minSdkVersion 23). Not for Play Store. Personal use: Smit + dad.
**Repo root:** `C:\Users\smitv\OneDrive\Desktop\Apps\Password_Manager`

---

## What We Are Building

PassMgr is a local-first, encrypted password manager for two specific people. No cloud, no accounts, no analytics. Data lives in on-device SQLite encrypted with AES-GCM-256. Core surfaces:

- **Lock screen** — master password + biometric unlock
- **Vault** — searchable list of saved passwords
- **Entry detail** — fields, copy-with-auto-clear, password history
- **Add / Edit entry** — form + inline password generator
- **Settings** — auto-lock, biometric, change master password, export/import backup
- **Chrome import** — CSV file picker + per-entry confirm flow
- **Setup (first launch)** — master password creation + recovery hint

## Why We Are Building It

Bitwarden is the right answer for strangers. For Smit's dad specifically, a simpler app he actually uses beats a powerful app he never opens. Custom app wins on simplicity and personal control. Scope stays strictly personal — never recommend to others, never put on Play Store.

## Source of Truth Documents

| File | Purpose |
|---|---|
| `PROJECT.md` | **Full project spec — READ THIS FIRST every session** |
| `PROJECT_DECISIONS.md` | Every architectural/code decision |
| `PROJECT_SESSIONS.md` | Session log, newest first |
| `DESIGN.md` | Visual design system — colors, typography, components |
| `password_manager_Full_mockup.html` | Full UI contract — all 16 screens |

If `PROJECT.md` and any other doc conflict, `PROJECT.md` wins for scope and `DESIGN.md` wins for visual design.

---

## Mandatory Skills (use every session, not optional)

| When | Skill | Why |
|---|---|---|
| Any new feature, redesign, behavior change | `superpowers:brainstorming` | Clarify intent + design before code. Hard gate before implementation. |
| Any UI / component / screen build | `frontend-design:frontend-design` | Match `DESIGN.md` + `password_manager_Full_mockup.html` contract. |
| 2+ independent tasks | `superpowers:dispatching-parallel-agents` | Parallelize file generation, screen builds, audits. |
| Bug or unexpected behavior | `superpowers:systematic-debugging` | Hypothesis → experiment, not random edits. |
| Before claiming done | `superpowers:verification-before-completion` | Run commands, confirm output. No "should work". |
| Implementing a written plan | `superpowers:executing-plans` | |

### External skill references

- **Superpowers** — `https://github.com/obra/superpowers` — installed as plugin; invoke via `Skill` tool.
- **UI/UX Pro Max Skill** — `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` — apply whenever doing UI work alongside `frontend-design`.
- **Awesome Design MD** — `https://github.com/voltagent/awesome-design-md` — reference catalog. Consult when writing or refreshing `DESIGN.md`.

---

## Hard Rules

1. **No implementation before brainstorming + plan** for non-trivial work. Trivial = single-line fix, typo, mechanical rename.
2. **Every UI change** reads `DESIGN.md` + `password_manager_Full_mockup.html`. No improvising visuals.
3. **Every session** appends to `PROJECT_SESSIONS.md` (newest first) with: what asked, what done, what blocked, what next.
4. **Every architectural decision** appends to `PROJECT_DECISIONS.md` with: context, options, choice, why, consequences.
5. **Caveman mode is active** (level: full). Drop articles/filler/pleasantries/hedging in conversational replies. Code, commits, security warnings: write normal.
6. **No emoji** in code or files unless owner explicitly requests.
7. **No new files** unless under explicit plan or one of the source-of-truth docs above.
8. **Verify before completion** — run `flutter analyze`, test the relevant feature, before declaring done.
9. Do not run `flutter` commands yourself — ask owner to run them and paste output.
10. **Never skip encryption correctness** — if a crypto decision is ambiguous, stop and ask. Silent encryption bugs are worse than no app.
11. **Version bumps are mandatory** on every meaningful change. Rules:
    - **Patch** `1.0.x` → bug fixes, UI tweaks, copy changes, small improvements
    - **Minor** `1.x.0` → new screen, new feature, new setting added
    - **Major** `x.0.0` → encryption algorithm change, data model migration, breaking change
    - Bump both `pubspec.yaml` (`version: x.y.z+buildNumber`) and the version string in `settings_screen.dart`. Build number increments by 1 each bump.

---

## Tech Stack (decided — do not revisit)

| Concern | Package | Why |
|---|---|---|
| Database | `sqflite` | Simpler than drift, enough for this scope |
| Secure key storage | `flutter_secure_storage` | Wraps Android Keystore |
| Encryption | `cryptography` (AES-GCM-256) | Authenticated encryption, prevents tampering |
| KDF | **Argon2id** — replaces PBKDF2 | Memory-hard KDF (parallelism=1, memory=64MB, iterations=3, hashLen=32). Required for short PIN (4-digit) to resist GPU brute-force on portable DB export. From `cryptography` package — no extra dependency. |
| Biometrics | `local_auth` | Standard Flutter package |
| File picking | `file_picker` | Standard |
| CSV parsing | `csv` | Standard |
| Screenshot block | `secure_application` | Sets FLAG_SECURE on Android |
| State management | `setState` / `ChangeNotifier` | App is small — do not over-engineer |

**Android minSdkVersion: 23** (Android 6.0) — required for fingerprint + Keystore APIs.

---

## Data Model (decided — do not change schema without decision log entry)

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

CREATE TABLE password_history (
  id                       INTEGER PRIMARY KEY AUTOINCREMENT,
  password_entry_id        INTEGER NOT NULL,
  old_password_encrypted   BLOB    NOT NULL,
  old_password_nonce       BLOB    NOT NULL,
  old_password_mac         BLOB    NOT NULL,
  changed_at               INTEGER NOT NULL,
  FOREIGN KEY (password_entry_id) REFERENCES passwords(id) ON DELETE CASCADE
);

CREATE TABLE app_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

**app_meta keys:** `kdf_salt`, `verifier_ciphertext`, `verifier_nonce`, `verifier_mac`, `recovery_hint`, `auto_lock_minutes`

---

## Encryption Rules (read before touching any crypto code)

- Algorithm: AES-GCM-256
- KDF: **Argon2id** (parallelism=1, memory=64MB, iterations=3) — memory-hard, replaces PBKDF2. Required for 4-digit PIN viability on portable DB. Class `Argon2id` from `cryptography` package.
- Salt: 32-byte random, stored in `app_meta` as `kdf_salt`
- Nonce: 12 bytes, fresh random per encryption. Never reuse.
- Verifier: encrypt known string `"VAULT_OK_v1"` at setup to verify PIN/password without storing it
- Unlock method: stored in `app_meta` as `unlock_type` (`pin` or `password`). PIN length in `pin_length`.
- PIN numpad: auto-submits at correct digit count. No OK button. Mirrors Samsung behavior.
- Key held in memory in `VaultSession`. Dropped on lock. Never written to disk unprotected.
- Biometric path: pre-derived key stored in `flutter_secure_storage` gated by `local_auth`
- Master password/PIN change: re-encrypt ALL entries in single SQLite transaction. Never partial.

---

## File Structure (planned)

```
lib/
  main.dart
  theme/app_theme.dart
  services/
    encryption_service.dart
    database_service.dart
    vault_session.dart
    biometric_service.dart
    backup_service.dart
  screens/
    setup_screen.dart
    lock_screen.dart
    vault_screen.dart
    entry_detail_screen.dart
    edit_entry_screen.dart
    settings_screen.dart
    chrome_import_screen.dart
  widgets/
    (shared widgets)
```

---

## Design Tokens (quick reference — full spec in DESIGN.md)

| Token | Value | Purpose |
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

Fonts: **Inter** for UI, **IBM Plex Mono** for passwords and secrets.

---

## Workflow for Any New Task

1. Read `CLAUDE.md` (this file). Read `PROJECT.md` for full spec.
2. Append session entry to `PROJECT_SESSIONS.md`.
3. Invoke `superpowers:brainstorming` if task is creative or non-trivial.
4. Invoke `frontend-design:frontend-design` if visual work is involved.
5. Implement.
6. Verify via `superpowers:verification-before-completion`.
7. Append to `PROJECT_DECISIONS.md` if a non-obvious choice was made.
8. Close session entry with outcome + next step.

---

## Active Constraints

- Personal use only. Never Play Store. Never recommend to third parties.
- No recovery path for master password — only the hint. Make this explicit to user in UI.
- No cloud sync, no accounts server, no analytics, no third-party SDKs beyond what is listed above.
- Existing vault data must survive every refactor. Migrations must be tested before shipping to dad's phone.
- Test biometric on dad's physical phone before declaring Day 3 done — emulator is unreliable for biometric.
