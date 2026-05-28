# Remaining Tasks

## Done (2026-05-20)
- [x] PIN unlock (Samsung-style numpad, auto-submit, shake on wrong PIN)
- [x] Fingerprint / biometric unlock on lock screen
- [x] Splash screen with logo placeholder + routing gate
- [x] Argon2id KDF replacing PBKDF2
- [x] Setup screen: choose PIN or password unlock method
- [x] Clipboard auto-clear: bumped 20s → 5 minutes
- [x] History panel stale cache bug fixed
- [x] Entry detail timestamp now shows HH:mm
- [x] Chrome import: resetAutoLockTimer fix + vault-locked dialog
- [x] Chrome import: duplicate detection (amber badge, pre-unchecked)

## Deferred to v2
- [ ] Email-based master password reset (requires server — conflicts with local-only design)

## Open Bugs (20-05-2026)
- [ ] "Vault is locked" message shown even though vault was never actually locked — investigate auto-lock false-positive
- [ ] History view: copy button missing (only reveal toggle exists — was in original mockup)

## Backlog Features
- [ ] Categories (low priority — can scroll 50 entries without them)
- [ ] Password generator: support up to 256 character passwords (currently likely capped lower)
- [ ] Import page: eye button too small — make bigger
- [ ] Import page: rethink/redesign the import UI
- [ ] Import page: what happens when importing CSV that was already imported? (duplicate detection is in, but re-test edge cases)
- [ ] "Change PIN" option in Settings screen (currently only "Change master password" which handles password mode — need PIN mode equivalent)
- [ ] App logo: swap Flutter-drawn lock icon placeholder with actual PNG/JPEG (owner will provide file)
- [ ] Test biometric on dad's physical phone (emulator unreliable for biometric)
