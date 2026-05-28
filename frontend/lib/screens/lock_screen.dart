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
    setState(() {
      _enteredPin += digit;
      _error = null;
    });
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
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _loading = false;
            _error = 'Wrong PIN';
          });
        }
      });
    }
  }

  Future<void> _unlockPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await VaultSession.instance.unlock(password);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/vault');
    } else {
      setState(() {
        _loading = false;
        _error = 'Wrong password';
      });
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.emeraldSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.emerald,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'PassMgr',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
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
          Text(
            _error!,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 12),
        // Hint
        if (_hint != null) ...[
          GestureDetector(
            onTap: () => setState(() => _showHint = !_showHint),
            child: Text(
              _showHint ? 'Hide hint' : 'Show hint',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.emerald,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          if (_showHint) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _hint!,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
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
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Center(
                      child: Icon(
                        Icons.fingerprint,
                        color: AppColors.emerald,
                        size: 34,
                      ),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.emerald, size: 28),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your master password to unlock.',
            style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
          ),
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
          ElevatedButton(
            onPressed: _loading ? null : _unlockPassword,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
          if (_biometricAvailable) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _tryBiometric,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.fingerprint, size: 22),
                label: const Text(
                  'Use biometrics',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
          if (_hint != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _showHint = !_showHint),
              child: Text(
                _showHint ? 'Hide hint' : 'Show recovery hint',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.emerald,
                  decoration: TextDecoration.underline,
                ),
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
                  border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _hint!,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
