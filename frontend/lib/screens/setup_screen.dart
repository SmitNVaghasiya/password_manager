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
            if (mounted) {
              setState(() {
                _confirmPin = '';
                _pinMismatch = true;
              });
            }
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
      final key = await _encryption.deriveKey(_pin, salt, memory: 16384, iterations: 2);
      final verifier =
          await _encryption.encrypt(EncryptionService.verifierPlaintext, key);

      await db.setMeta('kdf_salt', base64Encode(salt));
      await db.setMeta('kdf_version', 'argon2id_pin_v1');
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
      final verifier =
          await _encryption.encrypt(EncryptionService.verifierPlaintext, key);

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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.emerald,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Secure your vault',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
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
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
        const SizedBox(height: 8),
        Text(
          isConfirm ? 'Confirm your PIN' : 'Set your PIN',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
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
                  onTap: () => setState(() {
                    _pinLength = len;
                    _pin = '';
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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

        // Dots indicator
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
              final hasError = isConfirm && _pinMismatch;
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

        PinNumpad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 1c: Hint + create vault ─────────────────────────────────────────

  Widget _buildPinHint() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Almost done',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
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
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
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
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.inkMute,
                ),
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
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.inkMute,
                ),
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
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
              width: 44,
              height: 44,
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
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
