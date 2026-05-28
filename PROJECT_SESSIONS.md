# PROJECT_SESSIONS.md — PassMgr Session Log
> Append new sessions at the **top** (most recent first).
> Format: `## YYYY-MM-DD — Session Title`

---

## 2026-05-28 — Graphify Knowledge Graph + Doc Sync

**What was asked:** Continue graphify pipeline (was interrupted at Step 3B), then update all stale MD files.

**What was done:**
- `graphify-out/graph.html` — interactive visualization generated (389 nodes, 369 edges, 37 communities)
- `graphify-out/graph.json` — full graph with community detection + god nodes
- `graphify-out/graph_graphrag.json` — GraphRAG-ready export
- `graphify-out/GRAPH_REPORT.md` — plain-language report, Obsidian-compatible
- God nodes: `chrome_import_screen.dart`, `setup_screen.dart`, `settings_screen.dart`, `entry_detail_screen.dart`, `main.dart`
- `CLAUDE.md` — fixed KDF description: "Argon2 + bcrypt (layered)" → "Argon2id" (matches actual code — no bcrypt in implementation)
- `PROJECT_DECISIONS.md` — marked original PBKDF2 row [SUPERSEDED], corrected KDF decision to Argon2id with accurate params, added 2026-05-20 bug-fix decisions (clipboard timer, history cache, timestamp, import auto-lock, duplicate detection)
- `Remaining_tasks.md` — full rewrite: marked completed tasks done, organized open bugs vs backlog features

**What's blocked:** Nothing.

**Next session:** Run `flutter pub get` + `flutter analyze` to verify Argon2id API compiles. Test PIN flow on device. Test biometric on dad's phone.

---

## 2026-05-20 — PIN Unlock, Splash Screen, Argon2 KDF

**What was asked:** Add splash screen with logo. Replace PBKDF2 with Argon2id. Rewrite setup to offer PIN or password unlock. Rewrite lock screen with Samsung-style PIN numpad.

**What was done:**
- `pubspec.yaml` — added `argon2_flutter: ^2.0.0`, version bumped 1.1.1+4 → 1.2.0+5
- `lib/services/encryption_service.dart` — KDF swapped PBKDF2 (150k iter) → Argon2id (memory=64MB, iter=3, keyLen=32). UTF-8 encoding consistent across encrypt/decrypt.
- `lib/screens/splash_screen.dart` — NEW. Logo (lock icon + "PassMgr" wordmark) + animated 3-dot loader. Checks `kdf_salt` → routes to /setup or /lock after 700ms minimum.
- `lib/widgets/pin_numpad.dart` — NEW. Shared Samsung-style numpad (3×3 digits + backspace|0|rightAction slot).
- `lib/screens/setup_screen.dart` — Rewritten. Multi-step flow: choose PIN/password → PIN (length chips 4/5/6/8 + enter + confirm with shake on mismatch + hint) or password (text fields). Writes `unlock_type`, `pin_length`, `kdf_version=argon2id_v1` to app_meta.
- `lib/screens/lock_screen.dart` — Rewritten. PIN mode: logo + dots + numpad, auto-submits on last digit, shake+clear on wrong PIN, fingerprint in bottom-right slot. Password mode: existing text field design kept.
- `lib/main.dart` — SplashScreen as home, AppGate removed, LifecycleObserver moved to `builder` wrapper (cleaner pattern).
- `lib/screens/settings_screen.dart` — version string updated to v1.2.0.

**What's blocked:** Needs `flutter pub get` + `flutter analyze` to verify argon2_flutter API compiles. Logo PNG to be swapped in later.

**Next session:** Test on device. Add "Change PIN" to Settings screen. Verify biometric on dad's physical phone.

---

## 2026-05-20 — Four Bug Fixes (history, clipboard, timestamp, CSV import)

**What was asked:** Fix 4 bugs: (1) history panel shows stale/wrong password after edit, (2) clipboard not clearing + 20s too short, (3) time not shown on detail screen, (4) CSV import redirects to lock screen with no import.

**What was done:**
- `entry_detail_screen.dart` — Bug 1: Added `_decryptedHistory.clear(); _historyVisible.clear();` inside `_load()` setState block. Stale cached decrypted history values were persisting after reload, causing wrong passwords to show at wrong indices.
- `entry_detail_screen.dart` — Bug 2: Changed clipboard clear timer from `Duration(seconds: 20)` → `Duration(minutes: 5)`. Updated snackbar to note keyboard clipboard history limitation.
- `entry_detail_screen.dart` — Bug 3: `_formatDate` now appends `HH:mm` to the date string. Time was stored (millisecond timestamp) but never displayed.
- `chrome_import_screen.dart` — Bug 4: (a) `resetAutoLockTimer()` called after successful CSV parse so browsing entries doesn't trigger auto-lock. (b) `resetAutoLockTimer()` called at start of `_importSelected()`. (c) If vault IS locked when Import is tapped, show explanation dialog instead of silently wiping all routes and losing user selections.
- `pubspec.yaml` — version bumped `1.1.0+3` → `1.1.1+4` (patch fixes)
- `settings_screen.dart` — version display updated `v1.1.0` → `v1.1.1`

**What's blocked:** Nothing.

**Next session:** Test all 4 fixes on device. Then continue KDF/PIN/splash work from prior session plan.

---

## 2026-05-19 — Duplicate Detection on Chrome Import

**What was asked:** Detect duplicates when importing Chrome CSV — show "Already exists" badge, pre-uncheck duplicates, let user force-import if needed.

**What was done:**
- `chrome_import_screen.dart` — after CSV parse, load all vault entries and build `site_name|username` key set. Mark each CSV row as duplicate if key matches (case-insensitive). Duplicates: amber-tinted card, "Already exists" badge, pre-unchecked. Non-duplicates: pre-checked as before. Amber info banner at top: "X already in vault — unchecked. Y new." Done screen also shows duplicate count.
- `pubspec.yaml` — version bumped `1.0.1+2` → `1.1.0+3` (new feature = minor bump)
- `settings_screen.dart` — version display updated `v1.0.1` → `v1.1.0`

**What's blocked:** Nothing.

**Next session:** Test on device with a CSV that has known duplicates.

---

## 2026-05-19 — KDF Migration Plan, PIN Unlock, Splash Screen Design

**What was asked:** Decide on PIN vs password unlock, auto-submit behavior, KDF strength for portable DB, splash screen routing gate, email reset feasibility.

**What was decided:**
- KDF changed from PBKDF2 to **Argon2 + bcrypt layered** — memory-hard, required for 4-digit PIN over portable DB to resist GPU brute-force
- Primary unlock: **4-digit PIN** (configurable length, min 4) with Android numpad UI
- **Auto-submit** fires when digit count matches `pin_length` — no OK button, mirrors Samsung
- User chooses PIN or password at first launch setup. Stored in `app_meta` as `unlock_type`
- DB stays portable (export/restore on new phone) — PIN feeds KDF directly, not Android Keystore gate
- Splash screen added as Screen 1: logo + dots, checks `kdf_salt`, routes to Setup or Lock
- Email-based password reset deferred to v2 (requires server, conflicts with local-only design)

**What was changed in docs:**
- `PROJECT_DECISIONS.md` — 8 new decision entries in new "Unlock & KDF Decisions" section
- `PROJECT.md` — KDF row updated, Setup/Unlock/Splash sections rewritten
- `CLAUDE.md` — KDF row + Encryption Rules section updated

**What's blocked:** Code not yet changed. `encryption_service.dart` still uses PBKDF2. Argon2 package (`argon2_flutter` or equivalent) needs evaluation — check pub.dev compatibility with Android minSdk 23 before committing.

**Next session starts at:** Evaluate Argon2 Flutter package. Swap KDF in `encryption_service.dart`. Build splash screen. Build PIN numpad lock screen. Migration path for existing installs (none yet — no real data exists).

---

## 2026-05-19 — Import Redesign, Bug Fixes, Versioning Policy

**What was asked:** Redesign Chrome import to checkbox list. Fix `.enc` file picker crash. Add password visibility to import. Add "Show all / Hide all" toggle. Update README. Bump version. Add versioning rule to CLAUDE.md.

**What was done:**
- `chrome_import_screen.dart` — fully rewritten as scrollable checkbox list. All entries pre-selected. "Select all / Deselect all" + "Show all / Hide all" buttons in header bar. Per-row eye toggle. Sticky "Import X passwords" bottom button. Done screen with imported/skipped count.
- `backup_service.dart` — changed `FileType.custom` with `allowedExtensions: ['enc']` → `FileType.any`. Fixes crash on Android (`.enc` has no registered MIME type).
- `pubspec.yaml` — version bumped `1.0.0+1` → `1.0.1+2`
- `settings_screen.dart` — version display updated `v1.0.0` → `v1.0.1`
- `CLAUDE.md` — versioning policy added as Hard Rule 11 (patch/minor/major definitions)
- `README.md` — fully rewritten with app description, screen list, security table, stack, setup instructions
- `PROJECT_DECISIONS.md` — 3 new decision entries added
- `test/widget_test.dart` — fixed stale `MyApp` reference
- All `flutter analyze` warnings fixed: `withOpacity` → `withValues`, `activeColor` → `activeThumbColor`, unused imports removed, `BuildContext` async gap guarded

**What's blocked:** Nothing. Hot restart required after these changes (not hot reload).

**Next session starts at:** Test on physical device. Verify backup import works with `FileType.any`. Test biometric on dad's phone.

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
