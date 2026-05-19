# PROJECT_DECISIONS.md — PassMgr Decision Log
> Every architectural, technical, or product decision made across all sessions.
> **Never delete entries.** Mark outdated ones as `[SUPERSEDED]` and add the new decision below.

---

## Architecture Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-05-19 | **Local-first, no cloud sync** | Owner wants full data ownership. SQLite on device. No subscriptions, no telemetry, no third-party SDKs |
| 2026-05-19 | **Android only, minSdkVersion 23** | Fingerprint + Keystore APIs require API 23+. iOS adds complexity with no benefit for 2-person use case |
| 2026-05-19 | **`setState` / `ChangeNotifier` for state — no Riverpod/Bloc** | App is small (7 screens, 1 user session). Provider-level state is sufficient. Over-engineering state for 2 users is waste |
| 2026-05-19 | **`sqflite` over Drift** | Drift adds code-gen complexity. sqflite is sufficient for 3 tables and 2 users |
| 2026-05-19 | **`cryptography` package for AES-GCM-256** | Authenticated encryption — ciphertext tampering is detectable. GCM MAC prevents silent corruption |
| 2026-05-19 | **PBKDF2-HMAC-SHA256 at 150,000 iterations** | Slow on purpose. Brute-force defense for local encrypted file. 150k is current OWASP recommendation |
| 2026-05-19 | **VaultSession holds in-memory key — never persisted** | Key in memory only. Drop on lock. Biometric path uses flutter_secure_storage (Android Keystore-backed) — not plain storage |
| 2026-05-19 | **`flutter_secure_storage` for biometric key path** | Wraps Android Keystore. Key never touches SQLite or SharedPreferences |
| 2026-05-19 | **`secure_application` for FLAG_SECURE** | Android recent-apps preview leaks password screen. One flag fixes it. Required, not optional |

---

## Encryption Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-05-19 | **Fresh 12-byte random nonce per encryption** | AES-GCM nonce reuse with same key is catastrophic. Fresh nonce per write eliminates the risk |
| 2026-05-19 | **Nonce stored as separate column (not prepended to ciphertext)** | Decryption is explicit and readable. No offset arithmetic. Easier to audit |
| 2026-05-19 | **Verifier: encrypt `"VAULT_OK_v1"` to verify password** | Can verify password correctness without storing the password or its hash. Decrypt → compare string → success/fail |
| 2026-05-19 | **Recovery hint stored plain, never the password** | Hint helps user remember. Storing password/hash would be a security hole |
| 2026-05-19 | **Master password change: single SQLite transaction** | Partial re-encryption = some entries with old key, some with new = unrecoverable data loss. Transaction rolls back on failure |
| 2026-05-19 | **Dart GC limitation acknowledged for key zeroing** | Cannot zero memory in Dart like C. For threat model (lost phone, not memory dump attack), this is acceptable. Documented in PROJECT.md |

---

## Design Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-05-19 | **Emerald (`#1E5F4E`) as primary accent, not blue** | Security app feel without cliché tech-blue. Emerald signals trust and calm without being aggressive |
| 2026-05-19 | **Paper background (`#F5F1EA`) not pure white** | Off-white reduces eye strain for an app that may be opened in low light. Warm, not clinical |
| 2026-05-19 | **IBM Plex Mono for passwords and secrets** | Monospace makes secrets feel like secrets. Visually distinct from UI text. Easy to read character-by-character |
| 2026-05-19 | **No heavy shadows — hairline borders only** | Clean, minimal security feel. Shadows add visual noise. Hairline borders give structure without depth |
| 2026-05-19 | **16px card radius, 12px input radius** | Friendly without being playful. Consistent with modern Android Material 3 guidelines |
| 2026-05-19 | **DESIGN.md follows Google Stitch format** | Matches awesome-design-md collection standard. AI agents (including future Claude sessions) can read it as a structured design contract |
| 2026-05-19 | **Amber for warnings, not red** | Red is reserved for destructive/delete actions. Amber is for "pay attention but don't panic" (history warning, import no-date notice) |

---

## Product Scope Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-05-19 | **Never put on Play Store** | No security audit. No recovery path. Bitwarden is the right answer for strangers. This is a personal tool |
| 2026-05-19 | **No categories/folders/tags in v1** | Adds UI complexity for 2 users who can scroll a list of 50 entries. YAGNI |
| 2026-05-19 | **No 2FA/TOTP generation in v1** | Scope creep. Different security model (TOTP secrets need different storage treatment). Skip for now |
| 2026-05-19 | **No browser autofill / accessibility service** | Requires elevated Android permissions. Significant attack surface. Not needed for 2 users copy-pasting |
| 2026-05-19 | **Follow system theme instead of dark mode toggle** | Reduces settings surface area. User controls theme at OS level |
| 2026-05-19 | **Clipboard auto-clear: 20 seconds, app must stay open** | OS limitation — background timer may not fire if app is killed. Document this honestly in UI |
| 2026-05-19 | **URL field added to entry form** | Chrome CSV exports `url` column. Parsing it and storing it makes import useful. Missing from original mockup — added in full mockup |
| 2026-05-19 | **Recovery hint row added to Settings** | Was in data model but missing from settings screen. User must be able to update their hint |
| 2026-05-19 | **"Add all remaining" bulk option for Chrome import** | Per-entry review is correct default for first import. Bulk shortcut saves time when user trusts the batch |

---

## Known Issues / Deferred

| Date | Issue | Plan |
|---|---|---|
| 2026-05-19 | **Clipboard auto-clear fails if app killed before 20s** | OS limitation. Document in UI: "Clears in 20s if app stays open." |
| 2026-05-19 | **History items have no copy button** | Original mockup only has reveal toggle. Full mockup corrects this. Add copy button to history rows in implementation |
| 2026-05-19 | **Sort order not shown on vault home** | Low priority. Can add "Sort by: updated" indicator in v1.1 if needed |

---

## Things Explicitly Rejected

| Date | Rejected | Why |
|---|---|---|
| 2026-05-19 | Cloud sync / accounts server | Data ownership. 2-person scope makes cloud pointless and adds security risk |
| 2026-05-19 | Play Store distribution | No audit, no recovery path, Bitwarden is better for strangers |
| 2026-05-19 | Password strength meter | Nice to have. Skip for v1. Generator provides strong passwords so strength meter is mostly feedback theater |
| 2026-05-19 | Multi-vault / multi-user | 2 users, 2 phones, 2 separate installs. Not needed |
| 2026-05-19 | Riverpod / Bloc | Overkill for 7 screens and 2 users |
