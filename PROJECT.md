# PassMgr — Full Project Documentation

Everything discussed across our planning sessions, in one place.
Last updated: May 2026.

---

## 1. What this app is

A simple, local-only Android password manager built in Flutter.
Target users: **Smit and his dad only.** Not for Play Store. Not for friends.

The goal is (a) a real working app for two specific people, and (b) a solid Flutter + crypto learning project for the portfolio.

---

## 2. Why we built this instead of using Bitwarden

The "other apps are complicated or ask for money" framing is not fully accurate — Bitwarden's free tier is unlimited passwords, unlimited devices, no ads, and is audited by security researchers. For strangers, Bitwarden is the right answer.

For Smit's dad specifically, the trade-off flips: a simpler app he actually uses beats a powerful app he never opens. The custom app wins on simplicity and personal control. But the scope stays strictly personal — do not recommend this to others or put it on the Play Store.

---

## 3. The honest 1-day vs 3-day reality

The original instinct was "I can ship this in a day." That was wrong. Here is what was originally listed as "simple":

- Encrypted storage (AES-GCM-256 with PBKDF2 key derivation)
- Master password + fingerprint unlock
- Auto-lock with configurable timer and session management
- Full version history with old-password backup (also encrypted)
- Notes field per entry
- Chrome CSV import with per-entry confirmation flow
- Auto-timestamping on every insert
- Settings page

That is 8+ real features, several of which are the hard kind. The correct timeline is **3 focused days**, not 1. Compressing into 1 day produces something that looks done but has a silent encryption bug, which for a password manager is worse than no app at all.

**Why encryption specifically is the trap:**
One sentence from the user ("save with encryption ok") = a week of decisions in reality:
- Which algorithm? (AES-GCM-256)
- Where does the key come from? (PBKDF2-HMAC-SHA256 from master password + random salt)
- How many iterations? (150,000 — slow on purpose)
- Where is the salt stored? (SQLite `app_meta` table)
- What happens on master password change? (Re-encrypt every entry in a transaction)
- How do you verify the password without storing it? (Encrypt a known string at setup, try decrypting at unlock)

If any of those answers are wrong, the app gives false confidence and is worse than a plaintext file.

---

## 4. Things that were forgotten in the original plan

### Critical — security or data loss

| # | What | Why it matters |
|---|---|---|
| 1 | **Backup + restore** | Phone dies = all passwords gone. Need encrypted `.enc` export to Drive/email. |
| 2 | **Master password recovery** | No recovery path exists. User must be told this upfront. Recovery *hint* (not the password) stored in setup. |
| 3 | **Clipboard auto-clear** | Clipboard is readable by every app on the phone. Must clear after 20 seconds. |
| 4 | **FLAG_SECURE / screenshot block** | Android's recent-apps preview leaks password screen contents. One flag fixes it. |
| 5 | **Search bar** | 40 entries with no search is painful. Mandatory, not optional. |

### Important — usability

| # | What | Why it matters |
|---|---|---|
| 6 | **Password visibility toggle** | Eye icon to reveal password. Obvious in hindsight, easy to forget. |
| 7 | **Password generator** | Without it, users reuse weak passwords. Generator + length slider required. |
| 8 | **Empty states** | First open shows nothing. "No passwords yet — tap + to add one" is required. |
| 9 | **Confirm before delete** | One fat-finger tap should not delete a password forever. Dialog required. |
| 10 | **Splash routing gate** | More important than the splash visual. Boot → check if vault exists → Setup or Lock. |

### Skipped for v1 (do not get tempted)

- Cloud sync / accounts / login server
- Categories / folders / tags
- 2FA / TOTP code generation
- Browser autofill / accessibility service
- Dark mode toggle (follow system theme instead)
- Password strength meter
- Multi-vault / multi-user

---

## 5. Visual design system

Established for the mockup and carried into Flutter theme.

| Token | Value | Purpose |
|---|---|---|
| `paper` | `#F5F1EA` | App background |
| `ink` | `#0F1419` | Primary text |
| `inkSoft` | `#4A5159` | Secondary text |
| `inkMute` | `#8A8F97` | Placeholder, muted labels |
| `card` | `#FFFFFF` | Card backgrounds |
| `border` | `#E4DED2` | Hairline borders |
| `emerald` | `#1E5F4E` | Primary accent (security feel, not cliché tech-blue) |
| `emeraldSoft` | `#E8F0EC` | Emerald tint for avatars and backgrounds |
| `amber` | `#B45309` | Warnings |
| `amberSoft` | `#FBF1E2` | Amber tint backgrounds |
| `danger` | `#B91C1C` | Delete, errors |

**Typography:**
- UI: Inter (system fallback)
- Passwords: IBM Plex Mono — makes secrets feel like secrets

**Shape:** 16px card radius, 12px inputs, hairline borders, no heavy shadows. One column. Nothing crowded.

---

## 6. Screens built

### HTML mockup (6 screens, phone frames, side by side)
File: `password_manager_mockup.html`

| Screen | Purpose |
|---|---|
| 1 · Lock | Master password field + fingerprint option |
| 2 · Vault home | Search bar + entry list + FAB |
| 3 · Entry detail | Fields + copy buttons + history dropdown (shown expanded) |
| 4 · Edit / Add | Full form + inline password generator card |
| 5 · Settings | Security / Data / About groups with toggles |
| 6 · Chrome import | Per-entry confirm flow with progress bar, Skip/Add buttons |

**What the mockup deliberately left out** (simple variants, not worth a separate frame):
- "Wrong password" error state
- Master password setup flow (first launch)
- Confirm-delete dialog
- Copy-to-clipboard toast

**One thing added that was not asked for:** the amber warning on the edit screen — "Saving will keep the old password in History." Without this, users are scared to edit thinking they'll overwrite forever. Keep it.

---

## 7. Tech stack (decided, do not revisit)

| Concern | Package | Why |
|---|---|---|
| Database | `sqflite` | Simpler than drift, enough for this scope |
| Secure key storage | `flutter_secure_storage` | Wraps Android Keystore |
| Encryption | `cryptography` (AES-GCM-256) | Authenticated encryption, prevents tampering |
| KDF | **Argon2 + bcrypt (layered)** — replaces PBKDF2 | Memory-hard. 4-digit PIN as KDF input with PBKDF2 was GPU-crackable in seconds. Argon2 forces RAM per attempt; bcrypt adds configurable work factor. Together they make short PINs viable for a portable DB. |
| Biometrics | `local_auth` | Standard Flutter package |
| File picking | `file_picker` | Standard |
| CSV parsing | `csv` | Standard |
| Screenshot block | `secure_application` | Sets FLAG_SECURE on Android |
| State management | `setState` / `ChangeNotifier` | App is small — do not over-engineer |

**Android `minSdkVersion`: 23** (Android 6.0) — required for fingerprint + Keystore APIs.

---

## 8. Data model

Two tables. Do not merge them.

```sql
CREATE TABLE passwords (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  site_name             TEXT    NOT NULL,
  username              TEXT    NOT NULL,
  password_encrypted    BLOB    NOT NULL,
  password_nonce        BLOB    NOT NULL,
  password_mac          BLOB    NOT NULL,
  notes_encrypted       BLOB,
  notes_nonce           BLOB,
  notes_mac             BLOB,
  created_at            INTEGER NOT NULL,   -- unix ms
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

**app_meta rows used:**

| Key | Value |
|---|---|
| `kdf_salt` | base64-encoded 32-byte random salt |
| `verifier_ciphertext` | base64 — known plaintext encrypted at setup |
| `verifier_nonce` | base64 |
| `verifier_mac` | base64 |
| `recovery_hint` | plain text, user-written. Never the password itself. |
| `auto_lock_minutes` | `'1'`, `'5'`, or `'10'` |

**Why nonces are separate columns:** AES-GCM requires a unique nonce per encryption. Storing it next to the ciphertext keeps decryption straightforward. Never reuse a nonce with the same key — GCM breaks catastrophically.

---

## 9. Encryption design

Read this section twice before writing any crypto code. This is the part that, if wrong, makes the whole app pointless.

### First launch setup

1. User chooses unlock method: **PIN** or **Password**
   - PIN: user sets 4–8 digit PIN. Length stored in `app_meta` as `pin_length`.
   - Password: user enters master password (min 8 chars, confirmed twice).
2. Generate random 32-byte salt → store in `app_meta`
3. Derive 32-byte key: **Argon2(input, salt) → bcrypt(result)** — replaces PBKDF2
4. Encrypt fixed known string `"VAULT_OK_v1"` with that key → store ciphertext + nonce + MAC in `app_meta` as the verifier
5. Store `unlock_type` (`pin` or `password`) in `app_meta`
6. Store derived key in `flutter_secure_storage` gated by biometric (for fingerprint unlock path)
7. Prompt user to write a **recovery hint** — a clue only they understand. Store plain. Never store the actual password.

### Unlock flow

1. Read salt + verifier + `unlock_type` from `app_meta`
2. Show PIN numpad (if `unlock_type = pin`) or password text field (if `unlock_type = password`)
3. PIN numpad: auto-submit when digit count reaches `pin_length` — no OK button
4. Derive key from entered input + salt using Argon2+bcrypt
5. Try to decrypt verifier
6. If success → key correct, hold in memory (`VaultSession`), route to vault
7. If failure → "Wrong PIN" / "Wrong password" error. Return null, not throw.
8. For biometric unlock: read pre-stored key from `flutter_secure_storage` (gated by `local_auth`), skip steps 4–5

### Splash screen routing gate

- Boot → check `kdf_salt` in `app_meta`
- If missing → Setup screen (first launch)
- If present → Lock screen (returning user)
- Display: emerald logo + "PassMgr" + animated loading dots while checking

### Per-entry encryption

- Each password and notes field: generate fresh 12-byte nonce, AES-GCM encrypt with master key
- Store: ciphertext + nonce + MAC (16 bytes for GCM MAC)
- On read: fetch all three fields, decrypt with in-memory key

### On lock

- Zero out (drop reference to) the key variable in memory
- Pop all routes back to lock screen
- Force re-authentication

**Dart limitation:** you cannot zero memory in Dart the way you can in C. The GC will eventually free it. For this threat model (lost phone, not sophisticated memory dump attack), this is acceptable.

### Change master password

1. Verify old password, derive old key
2. Derive new key from new password (new random salt)
3. Decrypt every password + history + notes with old key
4. Re-encrypt everything with new key, **inside a single SQLite transaction**
5. Update verifier with new key
6. Show progress indicator — this is slow with many entries
7. **Critical:** if the transaction fails mid-way, the old data is still intact. Never commit partial re-encryption.

---

## 10. Files generated

### Flutter project files

| File | Purpose |
|---|---|
| `pubspec.yaml` | All dependencies pinned |
| `lib/theme/app_theme.dart` | Color tokens, ThemeData, button/input styles |
| `lib/services/encryption_service.dart` | AES-GCM-256 + PBKDF2, password generator |
| `lib/services/database_service.dart` | SQLite CRUD, `app_meta`, history logic |
| `lib/services/vault_session.dart` | In-memory key holder, lock/unlock, auto-lock timer |
| `lib/screens/setup_screen.dart` | First-launch master password creation |
| `lib/screens/lock_screen.dart` | Returning user unlock — master password + hint |
| `lib/screens/vault_screen.dart` | Main list with search, FAB, empty state |
| `lib/screens/edit_entry_screen.dart` | Add / Edit form with inline password generator |
| `lib/screens/entry_detail_screen.dart` | Detail view, copy with auto-clear, history dropdown |
| `lib/main.dart` | App entry, routing gate, lifecycle auto-lock observer |
| `TESTING.md` | Manual test checklist for all generated files |

### Still to generate

| File | Purpose |
|---|---|
| `lib/services/biometric_service.dart` | Wraps `local_auth` + `flutter_secure_storage` |
| `lib/services/backup_service.dart` | Encrypted export + import logic |
| `lib/screens/settings_screen.dart` | Auto-lock, change password, biometric, export, import |
| `lib/screens/chrome_import_screen.dart` | CSV file picker + per-entry confirm flow |
| `android/app/src/main/AndroidManifest.xml` | Biometric permission, FLAG_SECURE |
| `android/app/build.gradle` | minSdkVersion 23 |

---

## 11. Three-day build plan

### Day 1 — Foundation (the unsexy stuff that makes or breaks the app)

**Morning (3–4 hrs):**
- `flutter create`, set package name, set `minSdkVersion 23`
- Add all dependencies (`flutter pub get`)
- Folder structure: `lib/screens/`, `lib/services/`, `lib/models/`, `lib/widgets/`, `lib/theme/`
- Write `EncryptionService` + write encryption roundtrip tests before touching UI
- Write `DatabaseService` with table creation + raw CRUD

**Afternoon (4–5 hrs):**
- Master password setup screen (first-launch only)
- Lock screen (master password input)
- Routing gate: boot → check `kdf_salt` in `app_meta` → Setup or Lock
- Vault list screen (empty shell)
- Add entry screen wired to encrypted DB
- **Verify roundtrip:** add entry → close app → reopen → unlock → see decrypted entry

**End of Day 1:** working encrypted add + view, lock + unlock with master password. Nothing pretty. No history, no biometric, no settings. Test encryption roundtrip 10+ times before going to bed.

---

### Day 2 — Core features

**Morning (3–4 hrs):**
- Edit entry screen — on save, archive old password to `password_history` first
- History dropdown on entry detail — shows created date + past versions with dates
- Tap to reveal old password (toggle per row)
- Search bar on vault list (filter by site_name, case-insensitive)
- Password visibility toggle

**Afternoon (4–5 hrs):**
- Password generator widget (length slider 8–32, char-class toggles, generate button)
- Copy to clipboard with toast: "Copied — clears in 20s"
- Background timer to clear clipboard after 20 seconds
- Delete entry → confirmation dialog → cascade delete history rows
- `FLAG_SECURE` enabled
- Empty state: vault ("No passwords yet. Tap + to add your first.")
- Loading states and error snackbars on save failures

**End of Day 2:** functional password manager you'd actually use yourself, minus biometric and import.

---

### Day 3 — The harder stuff + polish

**Morning (3–4 hrs):**
- Biometric unlock (`local_auth` + `flutter_secure_storage`)
- Auto-lock on background (`WidgetsBindingObserver`, `AppLifecycleState`)
- Settings screen: auto-lock timer (1 / 5 / 10 min), change master password, recovery hint, export, import

**Afternoon (4–5 hrs):**
- Chrome CSV import (file picker → parse → per-entry confirm screen → insert)
- Auto-timestamp on import if Chrome's CSV has no date (it never does)
- Encrypted backup export → serialize all entries to JSON → AES-GCM encrypt → write `.enc` file → system share sheet
- Encrypted backup import → file picker → decrypt → merge into DB
- Test on **physical phone** (not emulator — biometric is unreliable on emulator)
- Fix bugs, sideload to dad's phone

---

## 12. Things that will go wrong (pre-mortem)

| Risk | Mitigation |
|---|---|
| Encryption "works" but bytes encoded wrong → silent corruption | Write encrypt → decrypt → assert equal tests on Day 1 morning. 50 entries before trusting it. |
| Biometric works on your phone, fails on dad's | Test on his phone Day 3 evening before declaring done |
| Clipboard auto-clear doesn't fire if app is killed before 20s | OS limitation. Document it. Tell user "clears in 20s if app stays open." |
| Crash mid re-encryption on master password change → half entries unreadable | Wrap in SQLite transaction. Backup DB file before starting. |
| User exports backup, forgets master password → backup also unreadable | Make this explicit in Settings > Export: "Requires your current master password to restore." |
| Chrome CSV has unicode in passwords → parse breaks | Use `csv` package's strict mode. Surface errors per row. Do not crash the whole import. |
| Hot reload makes crypto keys behave weirdly in dev | Always full restart, never hot reload, when testing crypto code. |

---

## 13. Chrome CSV import — one design note

The import flow as drawn shows one entry at a time with Skip/Add per entry. This is good for the first import ever. In practice, after 10 entries the user will just tap "Add" on everything.

**Recommendation before building this screen:** add a bulk-import option with a single confirmation at the end, in addition to the per-entry flow. The per-entry confirm is the right default for unfamiliar passwords. A "Add all remaining" shortcut saves time when the user trusts the batch.

Chrome's exported CSV format: `name, url, username, password, note`. The `created_at` field is never present. Always use current timestamp on import.

---

## 14. Dad-specific setup instructions

When handing the app to dad, do these things before he adds a single password:

1. **Set a recovery hint together.** Something only he will understand. Not the password itself. "Old phone PIN reversed" or similar.
2. **Export an encrypted backup immediately** during the onboarding flow, before adding anything. Force the habit while there is nothing to lose.
3. **Tell him out loud:** "If you forget the master password, all your passwords are gone. There is no recovery. The hint is your only help."
4. **Save the backup to Google Drive or WhatsApp to himself.** Not just in phone storage — that is also gone if the phone dies.
5. **Test the backup restore** before he relies on the app. Import the backup on a second device or reinstall, verify his entries come back.

---

## 15. Honest scope warning

Do not put this on the Play Store. Do not give it to friends.

Reasons:
1. Bitwarden is free, unlimited, audited by professional security researchers, and works everywhere. Recommending this app over Bitwarden to strangers is a disservice even if it works.
2. No recovery path exists. "Forget password = data gone." Fine for two known users, wrong for the public.
3. No security audit. Timing attacks on PBKDF2 comparison, side channels in nonce generation, and memory dump vectors exist and will not be caught without a real audit.

For Smit and his dad: the trade-off is fine and the app is the right choice. For everyone else: Bitwarden.
