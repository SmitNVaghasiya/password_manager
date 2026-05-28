# PIN Unlock, Splash Screen & Argon2 KDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace PBKDF2 with Argon2id, add a splash screen, rewrite setup to offer PIN or password unlock, and rewrite the lock screen with a Samsung-style PIN numpad.

**Architecture:** KDF swap is isolated to `encryption_service.dart`. Splash screen replaces `AppGate` spinner. Setup becomes a multi-step flow (choose method → set PIN/password). Lock screen branches on `unlock_type` from `app_meta` — PIN mode shows numpad, password mode keeps the existing text field. A shared `PinNumpad` widget is used by both setup and lock.

**Tech Stack:** Flutter, `argon2_flutter` (native Argon2id), `cryptography` (AES-GCM-256 unchanged), `sqflite`, `local_auth`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `frontend/pubspec.yaml` | Modify | Add argon2_flutter, bump version 1.1.0+3 → 1.2.0+4 |
| `frontend/lib/services/encryption_service.dart` | Modify | Swap `deriveKey` from PBKDF2 → Argon2id |
| `frontend/lib/screens/splash_screen.dart` | Create | Logo + dots loader, routes to /setup or /lock |
| `frontend/lib/widgets/pin_numpad.dart` | Create | Reusable Samsung-style numpad widget |
| `frontend/lib/screens/setup_screen.dart` | Rewrite | Multi-step: choose method → PIN setup or password setup |
| `frontend/lib/screens/lock_screen.dart` | Rewrite | PIN numpad mode + password mode, reads unlock_type from app_meta |
| `frontend/lib/main.dart` | Modify | Wire SplashScreen as home, add /splash route |

---

## Task 1: Add argon2_flutter dependency + version bump

**Files:**
- Modify: `frontend/pubspec.yaml`

- [ ] **Step 1: Add argon2_flutter and bump version**

Replace the `dependencies` block and `version` line in `frontend/pubspec.yaml`:

```yaml
version: 1.2.0+4

dependencies:
  flutter:
    sdk: flutter

  sqflite: ^2.3.3
  path: ^1.9.0
  cryptography: ^2.7.0
  flutter_secure_storage: ^9.2.2
  local_auth: ^2.3.0
  file_picker: ^8.1.2
  csv: ^6.0.0
  secure_application: ^4.1.0
  path_provider: ^2.1.3
  share_plus: ^10.0.0
  argon2_flutter: ^2.0.0
```

- [ ] **Step 2: Ask owner to run `flutter pub get` and paste any errors**

Expected: resolves without conflict. If `argon2_flutter` version not found, try `^1.0.0`.

---

## Task 2: Swap KDF to Argon2id in encryption_service.dart

**Files:**
- Modify: `frontend/lib/services/encryption_service.dart`

**Note:** `VaultSession.unlock(String input)` already passes its input directly to `deriveKey`. This means PIN strings (`"1234"`) go through Argon2id automatically — no changes needed to `vault_session.dart`.

- [ ] **Step 1: Rewrite encryption_service.dart**

Replace the entire file content:

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:argon2_flutter/argon2_flutter.dart';
import 'package:cryptography/cryptography.dart';

class EncryptionResult {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;

  const EncryptionResult({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });
}

class EncryptionService {
  static const _saltLength = 32;
  static const _nonceLength = 12;
  static const String verifierPlaintext = 'VAULT_OK_v1';

  final _aesGcm = AesGcm.with256bits(nonceLength: _nonceLength);
  final _argon2 = Argon2Flutter();

  Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
  }

  Uint8List generateNonce() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_nonceLength, (_) => rng.nextInt(256)));
  }

  Future<SecretKey> deriveKey(String password, Uint8List salt) async {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 3,
      memory: 1 << 16, // 65536 KB = 64 MB
      lanes: 1,
      desiredKeyLength: 32,
    );
    final keyBytes = await _argon2.deriveKey(
      parameters,
      Uint8List.fromList(utf8.encode(password)),
    );
    return SecretKey(keyBytes);
  }

  Future<EncryptionResult> encrypt(String plaintext, SecretKey key) async {
    final nonce = generateNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return EncryptionResult(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: nonce,
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<EncryptionResult> encryptBytes(Uint8List data, SecretKey key) async {
    final nonce = generateNonce();
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: key,
      nonce: nonce,
    );
    return EncryptionResult(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: nonce,
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<String?> decrypt(EncryptionResult result, SecretKey key) async {
    try {
      final secretBox = SecretBox(
        result.ciphertext,
        nonce: result.nonce,
        mac: Mac(result.mac),
      );
      final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> decryptBytes(EncryptionResult result, SecretKey key) async {
    try {
      final secretBox = SecretBox(
        result.ciphertext,
        nonce: result.nonce,
        mac: Mac(result.mac),
      );
      final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return Uint8List.fromList(plainBytes);
    } catch (_) {
      return null;
    }
  }

  String generatePassword({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    const syms = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    var charset = '';
    var required = <String>[];

    if (uppercase) { charset += upper; required.add(upper); }
    if (lowercase) { charset += lower; required.add(lower); }
    if (numbers)   { charset += nums;  required.add(nums); }
    if (symbols)   { charset += syms;  required.add(syms); }

    if (charset.isEmpty) charset = lower;

    final rng = Random.secure();
    final result = List<String>.generate(length, (_) => charset[rng.nextInt(charset.length)]);

    for (var i = 0; i < required.length && i < length; i++) {
      final set = required[i];
      result[i] = set[rng.nextInt(set.length)];
    }

    result.shuffle(rng);
    return result.join();
  }
}
```

- [ ] **Step 2: Ask owner to run `flutter analyze` and paste output**

Expected: no errors in encryption_service.dart. If `Argon2Flutter()` constructor or `Argon2Parameters` API differs, check `flutter pub deps` for installed argon2_flutter version and adjust.

- [ ] **Step 3: Commit**

```
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/services/encryption_service.dart
git commit -m "feat: swap KDF from PBKDF2 to Argon2id (memory=64MB, iter=3)"
```

---

## Task 3: Create splash_screen.dart

**Files:**
- Create: `frontend/lib/screens/splash_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _route();
  }

  @override
  void dispose() {
    _dotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    final initialized = await DatabaseService.instance.isVaultInitialized();
    if (!mounted) return;
    // Minimum visible time so the splash doesn't flash
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(initialized ? '/lock' : '/setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.emerald,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PassMgr',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 56),
            AnimatedBuilder(
              animation: _dotsCtrl,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3.0;
                    var t = (_dotsCtrl.value - delay) % 1.0;
                    if (t < 0) t += 1.0;
                    final opacity = t < 0.5
                        ? 0.3 + t * 2 * 0.7
                        : 1.0 - (t - 0.5) * 2 * 0.7;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add frontend/lib/screens/splash_screen.dart
git commit -m "feat: add splash screen with logo and routing gate"
```

---

## Task 4: Create shared PinNumpad widget

**Files:**
- Create: `frontend/lib/widgets/pin_numpad.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PinNumpad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  /// Optional widget in bottom-right slot (e.g. fingerprint button).
  /// Pass null to leave the slot empty.
  final Widget? rightAction;

  const PinNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(['1', '2', '3']),
        const SizedBox(height: 14),
        _row(['4', '5', '6']),
        const SizedBox(height: 14),
        _row(['7', '8', '9']),
        const SizedBox(height: 14),
        _bottomRow(),
      ],
    );
  }

  Widget _row(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits
          .map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _DigitKey(digit: d, onTap: () => onDigit(d)),
              ))
          .toList(),
    );
  }

  Widget _bottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _BackspaceKey(onTap: onBackspace),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _DigitKey(digit: '0', onTap: () => onDigit('0')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: 72,
            height: 72,
            child: rightAction,
          ),
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
              fontFamily: 'IBMPlexMono',
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.inkSoft,
            size: 26,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add frontend/lib/widgets/pin_numpad.dart
git commit -m "feat: add shared PinNumpad widget"
```

---

## Task 5: Rewrite setup_screen.dart

**Files:**
- Modify: `frontend/lib/screens/setup_screen.dart`

The setup screen is a multi-step flow managed by `_SetupStep` enum. PIN steps share one numpad; password steps use text fields. After completion both paths write to `app_meta` and navigate to `/vault`.

- [ ] **Step 1: Rewrite the file**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/encryption_service.dart';
import '../services/database_service.dart';
import '../services/vault_session.dart';
import '../widgets/pin_numpad.dart';

enum _SetupStep { chooseMethod, pinEnter, pinConfirm, pinHint, password }

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  _SetupStep _step = _SetupStep.chooseMethod;
  int _pinLength = 4;
  String _pin = '';
  String _confirmPin = '';
  bool _pinMismatch = false;

  final _hintController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  final _encryption = EncryptionService();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _hintController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_step == _SetupStep.pinEnter) {
      if (_pin.length >= _pinLength) return;
      setState(() => _pin += digit);
      if (_pin.length == _pinLength) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _step = _SetupStep.pinConfirm);
        });
      }
    } else if (_step == _SetupStep.pinConfirm) {
      if (_confirmPin.length >= _pinLength) return;
      setState(() {
        _confirmPin += digit;
        _pinMismatch = false;
      });
      if (_confirmPin.length == _pinLength) {
        if (_confirmPin == _pin) {
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) setState(() => _step = _SetupStep.pinHint);
          });
        } else {
          _shakeCtrl.forward(from: 0).then((_) {
            if (mounted) setState(() { _confirmPin = ''; _pinMismatch = true; });
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_step == _SetupStep.pinEnter && _pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_step == _SetupStep.pinConfirm && _confirmPin.isNotEmpty) {
      setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
  }

  Future<void> _createVaultPin() async {
    setState(() => _loading = true);
    try {
      final db = DatabaseService.instance;
      final salt = _encryption.generateSalt();
      final key = await _encryption.deriveKey(_pin, salt);
      final verifier = await _encryption.encrypt(EncryptionService.verifierPlaintext, key);

      await db.setMeta('kdf_salt', base64Encode(salt));
      await db.setMeta('kdf_version', 'argon2id_v1');
      await db.setMeta('unlock_type', 'pin');
      await db.setMeta('pin_length', _pinLength.toString());
      await db.setMeta('verifier_ciphertext', base64Encode(verifier.ciphertext));
      await db.setMeta('verifier_nonce', base64Encode(verifier.nonce));
      await db.setMeta('verifier_mac', base64Encode(verifier.mac));
      await db.setMeta('auto_lock_minutes', '5');
      final hint = _hintController.text.trim();
      if (hint.isNotEmpty) await db.setMeta('recovery_hint', hint);

      VaultSession.instance.unlockWithKey(key);
      if (mounted) Navigator.of(context).pushReplacementNamed('/vault');
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    }
  }

  Future<void> _createVaultPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final db = DatabaseService.instance;
      final salt = _encryption.generateSalt();
      final key = await _encryption.deriveKey(password, salt);
      final verifier = await _encryption.encrypt(EncryptionService.verifierPlaintext, key);

      await db.setMeta('kdf_salt', base64Encode(salt));
      await db.setMeta('kdf_version', 'argon2id_v1');
      await db.setMeta('unlock_type', 'password');
      await db.setMeta('verifier_ciphertext', base64Encode(verifier.ciphertext));
      await db.setMeta('verifier_nonce', base64Encode(verifier.nonce));
      await db.setMeta('verifier_mac', base64Encode(verifier.mac));
      await db.setMeta('auto_lock_minutes', '5');
      final hint = _hintController.text.trim();
      if (hint.isNotEmpty) await db.setMeta('recovery_hint', hint);

      VaultSession.instance.unlockWithKey(key);
      if (mounted) Navigator.of(context).pushReplacementNamed('/vault');
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(child: _buildStep()),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _SetupStep.chooseMethod:
        return _buildChooseMethod();
      case _SetupStep.pinEnter:
      case _SetupStep.pinConfirm:
        return _buildPinEntry();
      case _SetupStep.pinHint:
        return _buildPinHint();
      case _SetupStep.password:
        return _buildPasswordSetup();
    }
  }

  // ── Step 0: Choose unlock method ─────────────────────────────────────────

  Widget _buildChooseMethod() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.emerald, size: 28),
          ),
          const SizedBox(height: 24),
          const Text(
            'Secure your vault',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose how you want to unlock PassMgr each time.',
            style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 36),
          _MethodCard(
            icon: Icons.dialpad_rounded,
            title: 'PIN',
            subtitle: 'Quick and simple. Choose 4 to 8 digits.',
            badge: 'Recommended',
            onTap: () => setState(() => _step = _SetupStep.pinEnter),
          ),
          const SizedBox(height: 14),
          _MethodCard(
            icon: Icons.password_rounded,
            title: 'Password',
            subtitle: 'Longer text passphrase for maximum security.',
            onTap: () => setState(() => _step = _SetupStep.password),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_outlined, color: AppColors.amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If you forget your PIN or password, all vault data is lost permanently.',
                    style: TextStyle(fontSize: 13, color: AppColors.amber, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1a/1b: PIN entry / confirm ──────────────────────────────────────

  Widget _buildPinEntry() {
    final isConfirm = _step == _SetupStep.pinConfirm;
    final current = isConfirm ? _confirmPin : _pin;

    return Column(
      children: [
        const SizedBox(height: 32),
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.inkSoft),
              onPressed: () => setState(() {
                if (isConfirm) {
                  _step = _SetupStep.pinEnter;
                  _confirmPin = '';
                  _pinMismatch = false;
                } else {
                  _step = _SetupStep.chooseMethod;
                  _pin = '';
                }
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isConfirm ? 'Confirm your PIN' : 'Set your PIN',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          isConfirm ? 'Enter your PIN again' : 'Choose a length, then enter your PIN',
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),

        // Length chips (only on first entry)
        if (!isConfirm) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [4, 5, 6, 8].map((len) {
              final selected = len == _pinLength;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () => setState(() { _pinLength = len; _pin = ''; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.emerald : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.emerald : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '$len',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        const Spacer(),

        // Dots
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(isConfirm ? _shakeAnim.value : 0, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) {
              final filled = i < current.length;
              final hasError = isConfirm && _pinMismatch && !_shakeCtrl.isAnimating;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasError
                      ? AppColors.danger
                      : filled
                          ? AppColors.emerald
                          : Colors.transparent,
                  border: Border.all(
                    color: hasError
                        ? AppColors.danger
                        : filled
                            ? AppColors.emerald
                            : AppColors.inkMute,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),

        if (isConfirm && _pinMismatch) ...[
          const SizedBox(height: 10),
          const Text(
            'PINs do not match — try again',
            style: TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ],

        const Spacer(),

        // Numpad
        PinNumpad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 1c: PIN hint + create vault ─────────────────────────────────────

  Widget _buildPinHint() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Almost done',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add an optional recovery hint — a clue only you understand.',
            style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _hintController,
            decoration: const InputDecoration(
              labelText: 'Recovery hint (optional)',
              hintText: 'e.g. "Dog\'s name backwards"',
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _createVaultPin,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create vault'),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Password setup ────────────────────────────────────────────────

  Widget _buildPasswordSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.inkSoft),
            onPressed: () => setState(() => _step = _SetupStep.chooseMethod),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your vault',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your master password encrypts everything. There is no recovery if you forget it.',
            style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Master password',
              hintText: 'At least 8 characters',
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.inkMute),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              suffixIcon: IconButton(
                icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.inkMute),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _hintController,
            decoration: const InputDecoration(
              labelText: 'Recovery hint (optional)',
              hintText: 'e.g. "Old phone PIN reversed"',
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_outlined, color: AppColors.amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If you forget your master password, all passwords are lost permanently.',
                    style: TextStyle(fontSize: 13, color: AppColors.amber, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _createVaultPassword,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create vault'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Method choice card ────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.emerald, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkMute, size: 20),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add frontend/lib/screens/setup_screen.dart
git commit -m "feat: rewrite setup screen with PIN/password choice and PIN numpad"
```

---

## Task 6: Rewrite lock_screen.dart

**Files:**
- Modify: `frontend/lib/screens/lock_screen.dart`

Lock screen reads `unlock_type` and `pin_length` from `app_meta` on init and branches to PIN numpad or password field.

- [ ] **Step 1: Rewrite the file**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/vault_session.dart';
import '../services/biometric_service.dart';
import '../services/database_service.dart';
import '../widgets/pin_numpad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final _biometric = BiometricService();
  final _passwordController = TextEditingController();

  String _unlockType = 'pin';
  int _pinLength = 4;
  String _enteredPin = '';
  bool _loading = false;
  bool _showPassword = false;
  bool _showHint = false;
  bool _biometricAvailable = false;
  String? _hint;
  String? _error;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _init();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final db = DatabaseService.instance;
    final unlockType = await db.getMeta('unlock_type') ?? 'password';
    final pinLengthStr = await db.getMeta('pin_length') ?? '4';
    final hint = await db.getMeta('recovery_hint');
    final available = await _biometric.isAvailable();
    final enabled = await _biometric.isEnabled();

    if (!mounted) return;
    setState(() {
      _unlockType = unlockType;
      _pinLength = int.tryParse(pinLengthStr) ?? 4;
      _hint = hint;
      _biometricAvailable = available && enabled;
    });

    if (available && enabled) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final key = await _biometric.authenticateAndGetKey();
    if (key == null) return;
    VaultSession.instance.unlockWithKey(key);
    if (mounted) Navigator.of(context).pushReplacementNamed('/vault');
  }

  void _onDigit(String digit) {
    if (_loading || _enteredPin.length >= _pinLength) return;
    setState(() { _enteredPin += digit; _error = null; });
    if (_enteredPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 80), _unlockPin);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _unlockPin() async {
    setState(() => _loading = true);
    final success = await VaultSession.instance.unlock(_enteredPin);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/vault');
    } else {
      _shakeCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() { _enteredPin = ''; _loading = false; _error = 'Wrong PIN'; });
      });
    }
  }

  Future<void> _unlockPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final success = await VaultSession.instance.unlock(password);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/vault');
    } else {
      setState(() { _loading = false; _error = 'Wrong password'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: _unlockType == 'pin' ? _buildPinMode() : _buildPasswordMode(),
      ),
    );
  }

  // ── PIN mode ──────────────────────────────────────────────────────────────

  Widget _buildPinMode() {
    return Column(
      children: [
        const Spacer(),
        // Logo
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.emeraldSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.lock_outline_rounded, color: AppColors.emerald, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'PassMgr',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.3),
        ),
        const Spacer(),
        // Dots
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) {
              final filled = i < _enteredPin.length;
              final hasError = _error != null;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasError
                      ? AppColors.danger
                      : filled
                          ? AppColors.emerald
                          : Colors.transparent,
                  border: Border.all(
                    color: hasError
                        ? AppColors.danger
                        : filled
                            ? AppColors.emerald
                            : AppColors.inkMute,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 12),
        // Hint
        if (_hint != null)
          GestureDetector(
            onTap: () => setState(() => _showHint = !_showHint),
            child: Text(
              _showHint ? 'Hide hint' : 'Show hint',
              style: const TextStyle(fontSize: 13, color: AppColors.emerald, decoration: TextDecoration.underline),
            ),
          ),
        if (_showHint && _hint != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_hint!, style: const TextStyle(fontSize: 13, color: AppColors.ink), textAlign: TextAlign.center),
            ),
          ),
        ],
        const Spacer(),
        // Numpad
        PinNumpad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          rightAction: _biometricAvailable
              ? GestureDetector(
                  onTap: _tryBiometric,
                  child: Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Center(
                      child: Icon(Icons.fingerprint, color: AppColors.emerald, size: 34),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Password mode ─────────────────────────────────────────────────────────

  Widget _buildPasswordMode() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_outline, color: AppColors.emerald, size: 28),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome back',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text('Enter your master password to unlock.', style: TextStyle(fontSize: 15, color: AppColors.inkSoft)),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            autofocus: true,
            onSubmitted: (_) => _unlockPassword(),
            decoration: InputDecoration(
              labelText: 'Master password',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.inkMute),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _unlockPassword,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Unlock'),
          ),
          if (_biometricAvailable) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: _tryBiometric,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.fingerprint, size: 22),
                label: const Text('Use biometrics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
          if (_hint != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _showHint = !_showHint),
              child: Text(
                _showHint ? 'Hide hint' : 'Show recovery hint',
                style: const TextStyle(fontSize: 13, color: AppColors.emerald, decoration: TextDecoration.underline),
              ),
            ),
            if (_showHint) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
                ),
                child: Text(_hint!, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add frontend/lib/screens/lock_screen.dart
git commit -m "feat: rewrite lock screen with PIN numpad and password modes"
```

---

## Task 7: Wire SplashScreen in main.dart + update settings version display

**Files:**
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/screens/settings_screen.dart`

- [ ] **Step 1: Update main.dart**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secure_application/secure_application.dart';
import 'theme/app_theme.dart';
import 'services/vault_session.dart';
import 'screens/splash_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/vault_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/edit_entry_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chrome_import_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PassMgrApp());
}

class PassMgrApp extends StatelessWidget {
  const PassMgrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      child: MaterialApp(
        title: 'PassMgr',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/setup':  (_) => const SetupScreen(),
          '/lock':   (_) => const LockScreen(),
          '/vault':  (_) => const VaultScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/import': (_) => const ChromeImportScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/detail') {
            final entryId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entryId));
          }
          if (settings.name == '/edit') {
            final entryId = settings.arguments as int?;
            return MaterialPageRoute(builder: (_) => EditEntryScreen(entryId: entryId));
          }
          return null;
        },
        builder: (context, child) {
          return _LifecycleObserver(child: child!);
        },
      ),
    );
  }
}

class _LifecycleObserver extends StatefulWidget {
  final Widget child;
  const _LifecycleObserver({required this.child});
  @override
  State<_LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<_LifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (VaultSession.instance.isUnlocked) {
        VaultSession.instance.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 2: Update version string in settings_screen.dart**

Find the line displaying the version string (search for `v1.1.0` or `v1.0`) and update it to `v1.2.0`.

Ask owner to run:
```
grep -n "v1\." frontend/lib/screens/settings_screen.dart
```
Then update that line to `v1.2.0`.

- [ ] **Step 3: Commit**

```
git add frontend/lib/main.dart frontend/lib/screens/settings_screen.dart
git commit -m "feat: wire SplashScreen as app entry point, bump version to 1.2.0"
```

---

## Task 8: Final verification

- [ ] **Step 1: Ask owner to run `flutter analyze` in `frontend/` and paste output**

Expected: no errors. Common issues:
- `Argon2Flutter` constructor — if compile error, check `argon2_flutter` pub.dev README for exact class name
- `withValues(alpha:)` — correct for Flutter 3.x; if error revert to `withOpacity`

- [ ] **Step 2: Ask owner to hot-restart the app and verify**

Checklist:
- Splash screen shows logo + animated dots
- Routes to Setup on first launch (clear app data first if needed)
- Setup: PIN card and Password card visible
- PIN path: length chips (4/5/6/8), dots fill correctly, auto-advances to confirm, mismatch shakes, hint screen appears, vault created
- Password path: text fields, creates vault
- Lock screen (PIN mode): just dots + numpad, no extra headers, auto-submits, wrong PIN shakes
- Lock screen (password mode): text field, unlock button

- [ ] **Step 3: Update PROJECT_SESSIONS.md**

Append session entry at top of `PROJECT_SESSIONS.md`:

```markdown
## 2026-05-20 — PIN Unlock, Splash Screen, Argon2 KDF

**What was asked:** Add splash screen with logo. Replace PBKDF2 with Argon2id. Rewrite setup to offer PIN or password unlock. Rewrite lock screen with Samsung-style PIN numpad.

**What was done:**
- `pubspec.yaml` — added argon2_flutter, version bumped 1.1.0+3 → 1.2.0+4
- `encryption_service.dart` — KDF swapped from PBKDF2 (150k iter) to Argon2id (64MB/3iter/32byte). UTF-8 encoding used consistently.
- `screens/splash_screen.dart` — NEW. Logo + animated dots, routes to /setup or /lock
- `widgets/pin_numpad.dart` — NEW. Shared Samsung-style numpad (3×3 + backspace|0|rightSlot)
- `screens/setup_screen.dart` — Rewritten. Multi-step: choose PIN/password → PIN numpad setup (enter+confirm+hint) or password text fields
- `screens/lock_screen.dart` — Rewritten. PIN numpad mode (dots+numpad, auto-submit, shake on error, fingerprint slot) + password text field mode
- `main.dart` — SplashScreen as home, LifecycleObserver moved to builder wrapper, AppGate removed
- `settings_screen.dart` — version string updated to v1.2.0

**What's blocked:** Nothing. Logo PNG to be added later (swap lock icon placeholder).

**Next session:** Test biometric on dad's physical device. Add "Change PIN" to Settings screen.
```
