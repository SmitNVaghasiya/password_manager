import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';
import '../services/vault_session.dart';

class _CsvEntry {
  final String name;
  final String url;
  final String username;
  final String password;
  final String note;
  final bool isDuplicate;

  const _CsvEntry({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    required this.note,
    this.isDuplicate = false,
  });

  _CsvEntry withDuplicate(bool val) => _CsvEntry(
        name: name,
        url: url,
        username: username,
        password: password,
        note: note,
        isDuplicate: val,
      );
}

class ChromeImportScreen extends StatefulWidget {
  const ChromeImportScreen({super.key});

  @override
  State<ChromeImportScreen> createState() => _ChromeImportScreenState();
}

class _ChromeImportScreenState extends State<ChromeImportScreen> {
  final _encryption = EncryptionService();

  List<_CsvEntry> _entries = [];
  Set<int> _selected = {};
  Set<int> _passwordVisible = {};
  bool _allPasswordsVisible = false;
  bool _loading = false;
  bool _importing = false;
  bool _done = false;
  int _importedCount = 0;
  int _duplicateCount = 0;
  String? _parseError;

  bool get _allSelected =>
      _entries.isNotEmpty && _selected.length == _entries.length;

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _parseError = null;
    });

    VaultSession.suppressLock = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    VaultSession.suppressLock = false;

    if (result == null || result.files.single.path == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final content = await File(result.files.single.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(content);

      if (rows.isEmpty) throw Exception('Empty file');

      final rawEntries = <_CsvEntry>[];
      for (final row in rows.skip(1)) {
        if (row.length < 4) continue;
        final name = row[0].toString().trim();
        final url = row.length > 1 ? row[1].toString().trim() : '';
        final username = row.length > 2 ? row[2].toString().trim() : '';
        final password = row.length > 3 ? row[3].toString().trim() : '';
        final note = row.length > 4 ? row[4].toString().trim() : '';

        if (password.isEmpty) continue;
        rawEntries.add(_CsvEntry(
          name: name.isEmpty ? url : name,
          url: url,
          username: username,
          password: password,
          note: note,
        ));
      }

      if (rawEntries.isEmpty) throw Exception('No valid entries found in CSV');

      // Check duplicates against existing vault entries
      final existing = await DatabaseService.instance.getAllEntries();
      final existingKeys = <String>{};
      for (final e in existing) {
        existingKeys.add(
            '${e.siteName.toLowerCase()}|${e.username.toLowerCase()}');
      }

      final entries = rawEntries.map((e) {
        final key = '${e.name.toLowerCase()}|${e.username.toLowerCase()}';
        return e.withDuplicate(existingKeys.contains(key));
      }).toList();

      final dupeCount = entries.where((e) => e.isDuplicate).length;

      // Pre-select only non-duplicates
      final selected = <int>{};
      for (var i = 0; i < entries.length; i++) {
        if (!entries[i].isDuplicate) selected.add(i);
      }

      VaultSession.instance.resetAutoLockTimer();
      setState(() {
        _entries = entries;
        _selected = selected;
        _duplicateCount = dupeCount;
        _passwordVisible = {};
        _allPasswordsVisible = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _parseError = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected = Set.from(List.generate(_entries.length, (i) => i));
      }
    });
  }

  void _toggleEntry(int index) {
    VaultSession.instance.resetAutoLockTimer();
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _toggleAllPasswordsVisible() {
    setState(() {
      _allPasswordsVisible = !_allPasswordsVisible;
      if (_allPasswordsVisible) {
        _passwordVisible = Set.from(List.generate(_entries.length, (i) => i));
      } else {
        _passwordVisible.clear();
      }
    });
  }

  void _togglePasswordVisible(int index) {
    setState(() {
      if (_passwordVisible.contains(index)) {
        _passwordVisible.remove(index);
      } else {
        _passwordVisible.add(index);
      }
    });
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;

    VaultSession.instance.resetAutoLockTimer();

    if (!VaultSession.instance.isUnlocked) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Vault locked'),
            content: const Text('The vault locked due to inactivity. Unlock again to continue the import.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamedAndRemoveUntil('/lock', (r) => false);
                },
                child: const Text('Go to unlock'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _importing = true);

    final key = VaultSession.instance.key;
    final db = DatabaseService.instance;
    int count = 0;

    for (final index in _selected) {
      final entry = _entries[index];
      final now = DateTime.now().millisecondsSinceEpoch;
      final encPass = await _encryption.encrypt(entry.password, key);

      EncryptionResult? encNotes;
      if (entry.note.isNotEmpty) {
        encNotes = await _encryption.encrypt(entry.note, key);
      }

      await db.insertEntry(PasswordEntry(
        siteName: entry.name,
        username: entry.username,
        url: entry.url.isNotEmpty ? entry.url : null,
        passwordEncrypted: encPass.ciphertext,
        passwordNonce: encPass.nonce,
        passwordMac: encPass.mac,
        notesEncrypted: encNotes?.ciphertext,
        notesNonce: encNotes?.nonce,
        notesMac: encNotes?.mac,
        createdAt: now,
        updatedAt: now,
      ));
      count++;
    }

    setState(() {
      _importedCount = count;
      _importing = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Chrome')),
      body: _entries.isEmpty
          ? _buildPicker()
          : _done
              ? _buildDone()
              : _buildList(),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.emeraldSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.upload_file_outlined,
                color: AppColors.emerald, size: 28),
          ),
          const SizedBox(height: 20),
          const Text(
            'Import Chrome passwords',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Export from Chrome: Settings > Autofill > Passwords > Export.\nThen select the CSV file below.',
            style: TextStyle(
                fontSize: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_parseError!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            label: const Text('Select CSV file'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final newCount = _entries.where((e) => !e.isDuplicate).length;

    return Column(
      children: [
        // Duplicate notice banner
        if (_duplicateCount > 0)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.amberSoft,
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_duplicateCount already in vault — unchecked. '
                    '$newCount new.',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.amber,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),

        // Header bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleSelectAll,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _allSelected
                            ? AppColors.emerald
                            : Colors.transparent,
                        border: Border.all(
                          color: _allSelected
                              ? AppColors.emerald
                              : AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _allSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _allSelected ? 'Deselect all' : 'Select all',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _toggleAllPasswordsVisible,
                child: Row(
                  children: [
                    Icon(
                      _allPasswordsVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _allPasswordsVisible ? 'Hide all' : 'Show all',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_selected.length} of ${_entries.length} selected',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),

        // Scrollable list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _entries.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = _entries[i];
              final isSelected = _selected.contains(i);
              final pwVisible = _passwordVisible.contains(i);

              return GestureDetector(
                onTap: () => _toggleEntry(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: entry.isDuplicate
                        ? AppColors.amberSoft.withValues(alpha: 0.5)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.emerald
                          : entry.isDuplicate
                              ? AppColors.amber.withValues(alpha: 0.3)
                              : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.emerald
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.emerald
                                  : AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 13, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink),
                                  ),
                                ),
                                if (entry.isDuplicate)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberSoft,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.amber
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      'Already exists',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.amber),
                                    ),
                                  ),
                              ],
                            ),
                            if (entry.url.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                entry.url,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMute),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _FieldLine(
                                label: 'Username',
                                value: entry.username),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 72,
                                  child: Text('Password',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.inkMute,
                                          fontWeight:
                                              FontWeight.w600)),
                                ),
                                Expanded(
                                  child: pwVisible
                                      ? Text(
                                          entry.password,
                                          style: const TextStyle(
                                            fontFamily: AppTextStyles
                                                .monoFamily,
                                            fontSize: 12,
                                            color: AppColors.ink,
                                            letterSpacing: 0.5,
                                          ),
                                        )
                                      : const Text(
                                          '••••••••••',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.inkMute,
                                              letterSpacing: 2),
                                        ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _togglePasswordVisible(i),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(left: 6),
                                    child: Icon(
                                      pwVisible
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 16,
                                      color: AppColors.inkMute,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Sticky bottom button
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton(
            onPressed: (_selected.isEmpty || _importing)
                ? null
                : _importSelected,
            child: _importing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _selected.isEmpty
                        ? 'Select passwords to import'
                        : 'Import ${_selected.length} password${_selected.length == 1 ? '' : 's'}',
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final skipped = _entries.length - _importedCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.emerald, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Import complete',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Text(
              '$_importedCount imported  •  $skipped skipped',
              style: const TextStyle(
                  fontSize: 15, color: AppColors.inkSoft),
            ),
            if (_duplicateCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$_duplicateCount duplicates were left unchecked',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.inkMute),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .popUntil((r) => r.settings.name == '/vault'),
              child: const Text('Back to vault'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLine extends StatelessWidget {
  final String label;
  final String value;
  const _FieldLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMute,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
