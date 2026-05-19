import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/encryption_service.dart';
import '../services/database_service.dart';
import '../services/vault_session.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;
  final _encryption = EncryptionService();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _createVault() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final password = _passwordController.text;
      final db = DatabaseService.instance;

      final salt = _encryption.generateSalt();
      final key = await _encryption.deriveKey(password, salt);

      final verifier = await _encryption.encrypt(EncryptionService.verifierPlaintext, key);

      await db.setMeta('kdf_salt', base64Encode(salt));
      await db.setMeta('verifier_ciphertext', base64Encode(verifier.ciphertext));
      await db.setMeta('verifier_nonce', base64Encode(verifier.nonce));
      await db.setMeta('verifier_mac', base64Encode(verifier.mac));
      await db.setMeta('auto_lock_minutes', '5');

      final hint = _hintController.text.trim();
      if (hint.isNotEmpty) {
        await db.setMeta('recovery_hint', hint);
      }

      VaultSession.instance.unlockWithKey(key);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
      }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                  child: const Icon(Icons.lock_outline, color: AppColors.emerald, size: 28),
                ),
                const SizedBox(height: 24),
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
                  'Your master password encrypts everything. Choose carefully — there is no recovery if you forget it.',
                  style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Master password',
                    hintText: 'At least 8 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.inkMute,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.inkMute,
                      ),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recovery hint (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                const Text(
                  'A clue only you understand. Not the password itself.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkMute),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _hintController,
                  decoration: const InputDecoration(
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
                  onPressed: _loading ? null : _createVault,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create vault'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
