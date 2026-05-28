import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/vault_session.dart';
import '../services/biometric_service.dart';
import '../services/backup_service.dart';
import '../services/encryption_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _biometric = BiometricService();
  final _backup = BackupService();
  final _encryption = EncryptionService();

  String _autoLock = '5';
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loadingBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lock = await DatabaseService.instance.getMeta('auto_lock_minutes') ?? '5';
    final bioAvail = await _biometric.isAvailable();
    final bioEnabled = await _biometric.isEnabled();
    if (mounted) {
      setState(() {
        _autoLock = lock;
        _biometricAvailable = bioAvail;
        _biometricEnabled = bioEnabled;
      });
    }
  }

  Future<void> _setAutoLock(String minutes) async {
    await DatabaseService.instance.setMeta('auto_lock_minutes', minutes);
    setState(() => _autoLock = minutes);
  }

  Future<void> _toggleBiometric(bool enable) async {
    setState(() => _loadingBiometric = true);
    if (enable) {
      final key = await _biometric.authenticateAndGetKey();
      if (key == null) {
        // Enroll: store current session key
        await _biometric.storeKey(VaultSession.instance.key);
        setState(() { _biometricEnabled = true; _loadingBiometric = false; });
      } else {
        // Re-enable
        await _biometric.storeKey(VaultSession.instance.key);
        setState(() { _biometricEnabled = true; _loadingBiometric = false; });
      }
    } else {
      await _biometric.disable();
      setState(() { _biometricEnabled = false; _loadingBiometric = false; });
    }
  }

  Future<void> _changeMasterPassword() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangePasswordDialog(
        encryption: _encryption,
        onComplete: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      await _backup.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final count = await _backup.importBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count passwords.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Security'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _LabeledDropdown(
              label: 'Auto-lock',
              value: _autoLock,
              items: const {'1': '1 minute', '5': '5 minutes', '10': '10 minutes'},
              onChanged: _setAutoLock,
            ),
            if (_biometricAvailable) ...[
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Biometric unlock', style: TextStyle(fontSize: 15, color: AppColors.ink)),
                subtitle: const Text('Unlock with fingerprint', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                value: _biometricEnabled,
                activeThumbColor: AppColors.emerald,
                onChanged: _loadingBiometric ? null : _toggleBiometric,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              title: const Text('Change master password', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMute),
              onTap: _changeMasterPassword,
            ),
          ]),

          const SizedBox(height: 24),
          _SectionHeader('Data'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined, color: AppColors.emerald),
              title: const Text('Export encrypted backup', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('Requires master password to restore', style: TextStyle(fontSize: 12, color: AppColors.inkMute)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMute),
              onTap: _exportBackup,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download_outlined, color: AppColors.emerald),
              title: const Text('Import backup', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('Merge from .enc backup file', style: TextStyle(fontSize: 12, color: AppColors.inkMute)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMute),
              onTap: _importBackup,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined, color: AppColors.emerald),
              title: const Text('Import from Chrome CSV', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('chrome://settings/passwords > Export', style: TextStyle(fontSize: 12, color: AppColors.inkMute)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMute),
              onTap: () => Navigator.of(context).pushNamed('/import'),
            ),
          ]),

          const SizedBox(height: 24),
          _SectionHeader('About'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            const ListTile(
              title: Text('PassMgr', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              trailing: Text('v1.2.0', style: TextStyle(fontSize: 13, color: AppColors.inkMute)),
            ),
            const Divider(height: 1),
            const ListTile(
              title: Text('Encryption', style: TextStyle(fontSize: 15, color: AppColors.ink)),
              trailing: Text('AES-GCM-256', style: TextStyle(fontSize: 13, color: AppColors.inkMute, fontFamily: AppTextStyles.monoFamily)),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final EncryptionService encryption;
  final VoidCallback onComplete;

  const _ChangePasswordDialog({required this.encryption, required this.onComplete});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  double _progress = 0;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _loading = true; _error = null; _progress = 0.1; });

    try {
      final db = DatabaseService.instance;
      final enc = widget.encryption;

      // Verify old password
      final saltB64 = await db.getMeta('kdf_salt');
      if (saltB64 == null) throw Exception('Vault not initialized');
      final oldSalt = base64Decode(saltB64);
      final kdfVersion = await db.getMeta('kdf_version') ?? 'argon2id_v1';
      final wasPinVault = kdfVersion == 'argon2id_pin_v1';
      final oldKey = await enc.deriveKey(
        _oldCtrl.text,
        oldSalt,
        memory: wasPinVault ? 16384 : 65536,
        iterations: wasPinVault ? 2 : 3,
      );

      final cipherB64 = await db.getMeta('verifier_ciphertext');
      final nonceB64 = await db.getMeta('verifier_nonce');
      final macB64 = await db.getMeta('verifier_mac');
      final verified = await enc.decrypt(
        EncryptionResult(
          ciphertext: base64Decode(cipherB64!),
          nonce: base64Decode(nonceB64!),
          mac: base64Decode(macB64!),
        ),
        oldKey,
      );
      if (verified != EncryptionService.verifierPlaintext) {
        setState(() { _loading = false; _error = 'Wrong current password'; });
        return;
      }

      setState(() => _progress = 0.3);

      // Derive new key — change-password always upgrades to full params
      final newSalt = enc.generateSalt();
      final unlockType = await db.getMeta('unlock_type') ?? 'password';
      final newIsPinVault = unlockType == 'pin';
      final newKey = await enc.deriveKey(
        _newCtrl.text,
        newSalt,
        memory: newIsPinVault ? 16384 : 65536,
        iterations: newIsPinVault ? 2 : 3,
      );

      setState(() => _progress = 0.5);

      // Re-encrypt all entries
      await db.reEncryptAll(
        decryptBlob: (cipher, nonce, mac) async {
          final result = await enc.decryptBytes(
            EncryptionResult(ciphertext: cipher, nonce: nonce, mac: mac),
            oldKey,
          );
          if (result == null) throw Exception('Decryption failed during re-encryption');
          return result;
        },
        encryptBlob: (plaintext) async {
          final result = await enc.encryptBytes(plaintext, newKey);
          return {
            'ciphertext': result.ciphertext,
            'nonce': result.nonce,
            'mac': result.mac,
          };
        },
      );

      setState(() => _progress = 0.85);

      // Update verifier
      final newVerifier = await enc.encrypt(EncryptionService.verifierPlaintext, newKey);
      await db.setMeta('kdf_salt', base64Encode(newSalt));
      await db.setMeta('kdf_version', newIsPinVault ? 'argon2id_pin_v1' : 'argon2id_v1');
      await db.setMeta('verifier_ciphertext', base64Encode(newVerifier.ciphertext));
      await db.setMeta('verifier_nonce', base64Encode(newVerifier.nonce));
      await db.setMeta('verifier_mac', base64Encode(newVerifier.mac));

      // Update session key
      VaultSession.instance.unlockWithKey(newKey);

      setState(() => _progress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master password changed.')),
        );
        widget.onComplete();
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change master password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
              ),
            TextField(
              controller: _oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.emeraldSoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
              ),
              const SizedBox(height: 6),
              const Text('Re-encrypting all entries...', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : widget.onComplete,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: AppColors.inkMute,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final void Function(String) onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          const Spacer(),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            items: items.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }
}
