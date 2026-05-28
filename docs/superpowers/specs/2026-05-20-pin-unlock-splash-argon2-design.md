# PassMgr — PIN Unlock, Splash Screen, Argon2 KDF Design

**Date:** 2026-05-20
**Scope:** KDF migration, splash screen, PIN/password setup, PIN lock screen

---

## 1. KDF — Argon2id

- Replace PBKDF2 (150k iterations) with Argon2id
- Package: `argon2_flutter` (native Android, minSdk 23 compatible)
- Parameters: memory=65536 (64MB), iterations=3, parallelism=1, keyLength=32
- No migration needed — no real vault data exists yet
- Write `kdf_version=argon2id_v1` to app_meta on setup

## 2. Splash Screen

- New file: `lib/screens/splash_screen.dart`
- Replaces AppGate spinner in main.dart
- Content: centered lock icon + "PassMgr" wordmark + loading dots
- Logic: checks `kdf_salt` in DB → routes to /setup or /lock
- Logo placeholder: Flutter-drawn (swap PNG later)

## 3. Setup Screen — Rewritten

**Step 1:** Choose unlock method
- Two cards: PIN (recommended) | Password

**Step 2a — PIN:**
- Length chips: 4 / 5 / 6 / 8 (default 4)
- Dots row (count = chosen length)
- Samsung-style numpad (3×3 + backspace|0|blank)
- State: ENTER → CONFIRM (auto-advance on last digit)
- Recovery hint after confirm

**Step 2b — Password:**
- Existing text field flow (unchanged)

**app_meta written:** unlock_type, pin_length (PIN only), kdf_version, kdf_salt, verifier_ciphertext, verifier_nonce, verifier_mac

## 4. Lock Screen — Rewritten

**PIN mode:**
- Light theme (paper background), NOT dark
- Top: lock icon + "PassMgr"
- Middle: dots row (pin_length circles)
- Bottom: numpad 3×3 + backspace|0|fingerprint(if biometric) or blank
- Auto-submit on last digit; shake+clear on wrong PIN
- No OK button

**Password mode:**
- Existing design kept

## 5. Files Changed

| File | Change |
|------|--------|
| `pubspec.yaml` | Add argon2_flutter |
| `lib/services/encryption_service.dart` | Swap deriveKey to Argon2id |
| `lib/screens/splash_screen.dart` | NEW |
| `lib/screens/setup_screen.dart` | Full rewrite |
| `lib/screens/lock_screen.dart` | Full rewrite |
| `lib/main.dart` | Wire SplashScreen, add /splash route |
| `pubspec.yaml` | Version bump 1.1.0+3 → 1.2.0+4 |
