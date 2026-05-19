import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';
import '../services/vault_session.dart';

class EntryDetailScreen extends StatefulWidget {
  final int entryId;
  const EntryDetailScreen({super.key, required this.entryId});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final _encryption = EncryptionService();
  PasswordEntry? _entry;
  List<PasswordHistoryEntry> _history = [];
  String? _password;
  String? _notes;
  bool _showPassword = false;
  bool _historyExpanded = false;
  final Map<int, bool> _historyVisible = {};
  final Map<int, String?> _decryptedHistory = {};
  bool _loading = true;
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final key = VaultSession.instance.key;

    final entry = await db.getEntry(widget.entryId);
    if (entry == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final password = await _encryption.decrypt(
      EncryptionResult(
        ciphertext: entry.passwordEncrypted,
        nonce: entry.passwordNonce,
        mac: entry.passwordMac,
      ),
      key,
    );

    String? notes;
    if (entry.notesEncrypted != null) {
      notes = await _encryption.decrypt(
        EncryptionResult(
          ciphertext: entry.notesEncrypted!,
          nonce: entry.notesNonce!,
          mac: entry.notesMac!,
        ),
        key,
      );
    }

    final history = await db.getHistory(entry.id!);

    if (mounted) {
      setState(() {
        _entry = entry;
        _password = password;
        _notes = notes;
        _history = history;
        _loading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    VaultSession.instance.resetAutoLockTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied — clears in 20s')),
    );
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 20), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete password?'),
        content: Text('Delete "${_entry?.siteName}" permanently? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await DatabaseService.instance.deleteEntry(widget.entryId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _decryptHistoryEntry(int index) async {
    if (_decryptedHistory.containsKey(index)) return;
    final h = _history[index];
    final key = VaultSession.instance.key;
    final plain = await _encryption.decrypt(
      EncryptionResult(
        ciphertext: h.oldPasswordEncrypted,
        nonce: h.oldPasswordNonce,
        mac: h.oldPasswordMac,
      ),
      key,
    );
    if (mounted) setState(() => _decryptedHistory[index] = plain);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }

    final entry = _entry!;
    final date = DateTime.fromMillisecondsSinceEpoch(entry.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.siteName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context)
                  .pushNamed('/edit', arguments: entry.id)
                  .then((_) => _load());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(children: [
            _FieldRow(
              label: 'Username',
              value: entry.username,
              onCopy: () => _copyToClipboard(entry.username, 'Username'),
            ),
            const Divider(height: 1),
            _PasswordRow(
              password: _password ?? '',
              visible: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
              onCopy: () => _copyToClipboard(_password ?? '', 'Password'),
            ),
            if (entry.url != null && entry.url!.isNotEmpty) ...[
              const Divider(height: 1),
              _FieldRow(
                label: 'URL',
                value: entry.url!,
                onCopy: () => _copyToClipboard(entry.url!, 'URL'),
              ),
            ],
          ]),

          if (_notes != null && _notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notes', style: TextStyle(fontSize: 12, color: AppColors.inkMute, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(_notes!, style: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.5)),
                  ],
                ),
              ),
            ]),
          ],

          const SizedBox(height: 12),
          _SectionCard(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.inkMute),
                  const SizedBox(width: 8),
                  Text(
                    'Updated ${_formatDate(date)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ]),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(children: [
              InkWell(
                onTap: () => setState(() => _historyExpanded = !_historyExpanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 10),
                      Text(
                        'Password history (${_history.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink),
                      ),
                      const Spacer(),
                      Icon(
                        _historyExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.inkMute,
                      ),
                    ],
                  ),
                ),
              ),
              if (_historyExpanded)
                ...List.generate(_history.length, (i) {
                  final h = _history[i];
                  final hDate = DateTime.fromMillisecondsSinceEpoch(h.changedAt);
                  final visible = _historyVisible[i] ?? false;
                  final decrypted = _decryptedHistory[i];

                  return Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(hDate),
                                    style: const TextStyle(fontSize: 12, color: AppColors.inkMute),
                                  ),
                                  const SizedBox(height: 4),
                                  visible && decrypted != null
                                      ? Text(
                                          decrypted,
                                          style: const TextStyle(
                                            fontFamily: AppTextStyles.monoFamily,
                                            fontSize: 13,
                                            color: AppColors.ink,
                                          ),
                                        )
                                      : const Text(
                                          '••••••••••••',
                                          style: TextStyle(fontSize: 13, color: AppColors.inkMute, letterSpacing: 2),
                                        ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.inkMute,
                              ),
                              onPressed: () async {
                                await _decryptHistoryEntry(i);
                                setState(() => _historyVisible[i] = !visible);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
            ]),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_month(dt.month)} ${dt.year}';
  }

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

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

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _FieldRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkMute, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.inkMute),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  final String password;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  const _PasswordRow({
    required this.password,
    required this.visible,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password', style: TextStyle(fontSize: 11, color: AppColors.inkMute, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                visible
                    ? Text(
                        password,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.monoFamily,
                          fontSize: 15,
                          color: AppColors.ink,
                          letterSpacing: 0.5,
                        ),
                      )
                    : const Text(
                        '••••••••••••',
                        style: TextStyle(fontSize: 15, color: AppColors.inkMute, letterSpacing: 4),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: AppColors.inkMute,
            ),
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.inkMute),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
