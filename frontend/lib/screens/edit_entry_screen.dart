import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';
import '../services/vault_session.dart';

class EditEntryScreen extends StatefulWidget {
  final int? entryId;
  const EditEntryScreen({super.key, this.entryId});

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _urlController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();

  bool _showPassword = false;
  bool _showGenerator = false;
  bool _loading = false;
  bool _isEdit = false;

  final _encryption = EncryptionService();

  // Generator state
  int _genLength = 16;
  bool _genUppercase = true;
  bool _genLowercase = true;
  bool _genNumbers = true;
  bool _genSymbols = true;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _isEdit = widget.entryId != null;
    if (_isEdit) {
      _showPassword = true;
      _loadEntry();
    } else {
      _generate();
    }
  }

  @override
  void dispose() {
    _siteController.dispose();
    _usernameController.dispose();
    _urlController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final entry = await DatabaseService.instance.getEntry(widget.entryId!);
    if (entry == null) { if (mounted) Navigator.of(context).pop(); return; }

    final key = VaultSession.instance.key;
    final password = await _encryption.decrypt(
      EncryptionResult(
        ciphertext: entry.passwordEncrypted,
        nonce: entry.passwordNonce,
        mac: entry.passwordMac,
      ),
      key,
    );

    String notes = '';
    if (entry.notesEncrypted != null) {
      notes = await _encryption.decrypt(
            EncryptionResult(
              ciphertext: entry.notesEncrypted!,
              nonce: entry.notesNonce!,
              mac: entry.notesMac!,
            ),
            key,
          ) ??
          '';
    }

    if (mounted) {
      setState(() {
        _siteController.text = entry.siteName;
        _usernameController.text = entry.username;
        _urlController.text = entry.url ?? '';
        _passwordController.text = password ?? '';
        _notesController.text = notes;
      });
    }
  }

  void _generate() {
    final pw = _encryption.generatePassword(
      length: _genLength,
      uppercase: _genUppercase,
      lowercase: _genLowercase,
      numbers: _genNumbers,
      symbols: _genSymbols,
    );
    setState(() => _generatedPassword = pw);
  }

  void _useGenerated() {
    setState(() {
      _passwordController.text = _generatedPassword;
      _showGenerator = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final key = VaultSession.instance.key;
      final db = DatabaseService.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final encPass = await _encryption.encrypt(_passwordController.text, key);

      EncryptionResult? encNotes;
      final notes = _notesController.text.trim();
      if (notes.isNotEmpty) {
        encNotes = await _encryption.encrypt(notes, key);
      }

      if (_isEdit) {
        final existing = await db.getEntry(widget.entryId!);
        if (existing == null) return;

        await db.updateEntry(
          existing.copyWith(
            siteName: _siteController.text.trim(),
            username: _usernameController.text.trim(),
            url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
            passwordEncrypted: encPass.ciphertext,
            passwordNonce: encPass.nonce,
            passwordMac: encPass.mac,
            notesEncrypted: encNotes?.ciphertext,
            notesNonce: encNotes?.nonce,
            notesMac: encNotes?.mac,
            updatedAt: now,
          ),
          archiveOldPassword: true,
        );
      } else {
        await db.insertEntry(PasswordEntry(
          siteName: _siteController.text.trim(),
          username: _usernameController.text.trim(),
          url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
          passwordEncrypted: encPass.ciphertext,
          passwordNonce: encPass.nonce,
          passwordMac: encPass.mac,
          notesEncrypted: encNotes?.ciphertext,
          notesNonce: encNotes?.nonce,
          notesMac: encNotes?.mac,
          createdAt: now,
          updatedAt: now,
        ));
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit entry' : 'New entry'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.emerald)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: AppColors.amber, size: 17),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Saving will move the current password to History.',
                        style: TextStyle(fontSize: 13, color: AppColors.amber, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

            _buildField('Site name', _siteController, required: true),
            const SizedBox(height: 12),
            _buildField('Username', _usernameController, required: true),
            const SizedBox(height: 12),
            _buildField('URL', _urlController, keyboardType: TextInputType.url),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              style: const TextStyle(fontFamily: AppTextStyles.monoFamily, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.inkMute,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_fix_high_outlined, color: AppColors.emerald, size: 20),
                      tooltip: 'Generate password',
                      onPressed: () => setState(() => _showGenerator = !_showGenerator),
                    ),
                  ],
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),

            if (_showGenerator) ...[
              const SizedBox(height: 12),
              _buildGenerator(),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _buildGenerator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password generator',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emerald),
          ),
          const SizedBox(height: 12),
          if (_generatedPassword.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _generatedPassword,
                style: const TextStyle(
                  fontFamily: AppTextStyles.monoFamily,
                  fontSize: 14,
                  color: AppColors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Length', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              const SizedBox(width: 8),
              Text('$_genLength', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emerald)),
              Expanded(
                child: Slider(
                  value: _genLength.toDouble(),
                  min: 8,
                  max: 32,
                  divisions: 24,
                  activeColor: AppColors.emerald,
                  onChanged: (v) => setState(() { _genLength = v.round(); _generate(); }),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              _Toggle('A-Z', _genUppercase, (v) { _genUppercase = v; _generate(); }),
              _Toggle('a-z', _genLowercase, (v) { _genLowercase = v; _generate(); }),
              _Toggle('0-9', _genNumbers, (v) { _genNumbers = v; _generate(); }),
              _Toggle('#!@', _genSymbols, (v) { _genSymbols = v; _generate(); }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _generate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _generatedPassword.isNotEmpty ? _useGenerated : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Use this'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatefulWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _Toggle(this.label, this.value, this.onChanged);

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(widget.label, style: const TextStyle(fontSize: 12)),
      selected: widget.value,
      onSelected: widget.onChanged,
      selectedColor: AppColors.emerald.withValues(alpha: 0.15),
      checkmarkColor: AppColors.emerald,
      labelStyle: TextStyle(
        color: widget.value ? AppColors.emerald : AppColors.inkSoft,
        fontWeight: widget.value ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: widget.value ? AppColors.emerald.withValues(alpha: 0.4) : AppColors.border,
      ),
    );
  }
}
