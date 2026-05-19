# PROJECT_SESSIONS.md — PassMgr Session Log
> Append new sessions at the **top** (most recent first).
> Format: `## YYYY-MM-DD — Session Title`

---

## 2026-05-19 — Full App Code Generation

**What was asked:** Build the complete Flutter app — all files, one by one, from scratch. Fresh `flutter create` scaffold existed; no dependencies or screens.

**What was done:**
- Wrote design spec → `docs/superpowers/specs/2026-05-19-passmgr-full-app-design.md`
- `pubspec.yaml` — all deps (sqflite, cryptography, local_auth, flutter_secure_storage, file_picker, csv, secure_application, path_provider, share_plus)
- `android/app/build.gradle.kts` — minSdk = 23
- `android/app/src/main/AndroidManifest.xml` — USE_BIOMETRIC, USE_FINGERPRINT, allowBackup=false
- `lib/theme/app_theme.dart` — full color tokens, typography (IBM Plex Mono), ThemeData
- `lib/services/encryption_service.dart` — AES-GCM-256 + PBKDF2-HMAC-SHA256 (150k iterations) + password generator
- `lib/services/database_service.dart` — SQLite CRUD, app_meta, history archiving, re-encryption helper
- `lib/services/vault_session.dart` — in-memory key, lock/unlock, auto-lock timer, ChangeNotifier
- `lib/services/biometric_service.dart` — local_auth + flutter_secure_storage (Android Keystore)
- `lib/services/backup_service.dart` — AES-GCM encrypted export (.enc) + import, share sheet
- `lib/main.dart` — routing gate, lifecycle observer (auto-lock on background), FLAG_SECURE via SecureApplication
- `lib/screens/setup_screen.dart` — first-launch master password + recovery hint
- `lib/screens/lock_screen.dart` — master password + biometric unlock, hint reveal
- `lib/screens/vault_screen.dart` — search, list with avatars, FAB, empty state
- `lib/screens/entry_detail_screen.dart` — fields, copy+auto-clear (20s), history accordion with decrypt-on-reveal
- `lib/screens/edit_entry_screen.dart` — add/edit form, inline password generator (slider + char toggles), amber warning banner
- `lib/screens/settings_screen.dart` — auto-lock, biometric toggle, change master password (full re-encrypt in transaction), export, import, Chrome import link
- `lib/screens/chrome_import_screen.dart` — CSV picker, per-entry confirm flow, Add all remaining, progress bar, done summary
- `test/encryption_test.dart` — PBKDF2 determinism, AES-GCM roundtrip x50, nonce uniqueness, wrong-key null return, password generator constraints

**What's blocked:**
- IBM Plex Mono font files need to be added to `frontend/fonts/` (download from Google Fonts). App works without them but passwords will render in system mono font.
- Run `flutter pub get` to install dependencies.
- Run `flutter test` to verify encryption tests pass before any UI testing.
- Test biometric on physical device — emulator biometric is unreliable.

**Next session starts at:** Run `flutter analyze`, fix any issues, then run on physical Android device (minSdk 23 = Android 6+).

---

## 2026-05-19 — Project Setup: Docs, Design System, Full Mockup

**What was asked:** Generate DESIGN.md, full 16-screen mockup HTML, CLAUDE.md, PROJECT_SESSIONS.md, PROJECT_DECISIONS.md. Analyze awesome-design-md repo format. Discuss HTML UI and missing screens.

**What was done:**
- Analyzed `https://github.com/voltagent/awesome-design-md` — DESIGN.md format is Google Stitch standard with 9 sections
- Reviewed existing `PROJECT.md` and `password_manager_mockup.html` (6 screens)
- Identified 10 missing screens: Setup, Splash/routing gate, Wrong password error, Empty vault, Confirm delete dialog, Copy toast, Master password change, Export confirmation, Restore from backup, Setup complete
- Generated `DESIGN.md` — full design system using Stitch format, PassMgr-specific tokens
- Generated `password_manager_Full_mockup.html` — 16 screens in phone frames
- Generated `CLAUDE.md` — project context, hard rules, tech stack, workflow
- Generated `PROJECT_SESSIONS.md` (this file)
- Generated `PROJECT_DECISIONS.md` — all decisions from PROJECT.md documented

**UI feedback noted:**
- History items need copy button (not just reveal toggle)
- Import screen missing "Add all remaining" bulk shortcut
- URL field absent from edit form (Chrome CSV has it)
- Settings missing Recovery Hint row
- Vault home missing sort order indicator

**What's blocked:** Nothing. Flutter project not yet created.

**Next session starts at:** Run `flutter create`, scaffold folder structure, write `EncryptionService` + roundtrip tests (Day 1 morning per PROJECT.md plan).

---

<!-- Add new sessions above this line -->
