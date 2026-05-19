import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/vault_session.dart';
import '../services/biometric_service.dart';
import '../services/database_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  final _biometric = BiometricService();
  bool _showPassword = false;
  bool _loading = false;
  bool _biometricAvailable = false;
  bool _showHint = false;
  String? _hint;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadHint();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await _biometric.isAvailable();
    final enabled = await _biometric.isEnabled();
    if (mounted) {
      setState(() => _biometricAvailable = available && enabled);
    }
    if (available && enabled) {
      _tryBiometric();
    }
  }

  Future<void> _loadHint() async {
    final hint = await DatabaseService.instance.getMeta('recovery_hint');
    if (mounted) setState(() => _hint = hint);
  }

  Future<void> _tryBiometric() async {
    final key = await _biometric.authenticateAndGetKey();
    if (key == null) return;
    VaultSession.instance.unlockWithKey(key);
    if (mounted) Navigator.of(context).pushReplacementNamed('/vault');
  }

  Future<void> _unlock() async {
    final password = _controller.text;
    if (password.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    final success = await VaultSession.instance.unlock(password);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/vault');
    } else {
      setState(() {
        _loading = false;
        _error = 'Wrong master password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                controller: _controller,
                obscureText: !_showPassword,
                autofocus: true,
                onSubmitted: (_) => _unlock(),
                decoration: InputDecoration(
                  labelText: 'Master password',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.inkMute,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _unlock,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
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
        ),
      ),
    );
  }
}
