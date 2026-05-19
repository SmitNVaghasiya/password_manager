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

  const _CsvEntry({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    required this.note,
  });
}

class ChromeImportScreen extends StatefulWidget {
  const ChromeImportScreen({super.key});

  @override
  State<ChromeImportScreen> createState() => _ChromeImportScreenState();
}

class _ChromeImportScreenState extends State<ChromeImportScreen> {
  final _encryption = EncryptionService();

  List<_CsvEntry> _entries = [];
  int _current = 0;
  int _added = 0;
  int _skipped = 0;
  bool _done = false;
  bool _loading = false;
  String? _parseError;
  bool _addingAll = false;

  Future<void> _pickFile() async {
    setState(() { _loading = true; _parseError = null; });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final content = await File(result.files.single.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(content);

      if (rows.isEmpty) throw Exception('Empty file');

      // Chrome CSV header: name, url, username, password, note
      // Skip header row
      final dataRows = rows.skip(1).toList();
      final entries = <_CsvEntry>[];

      for (final row in dataRows) {
        if (row.length < 4) continue;
        final name = row[0].toString().trim();
        final url = row.length > 1 ? row[1].toString().trim() : '';
        final username = row.length > 2 ? row[2].toString().trim() : '';
        final password = row.length > 3 ? row[3].toString().trim() : '';
        final note = row.length > 4 ? row[4].toString().trim() : '';

        if (password.isEmpty) continue; // skip empty password rows
        entries.add(_CsvEntry(
          name: name.isEmpty ? url : name,
          url: url,
          username: username,
          password: password,
          note: note,
        ));
      }

      if (entries.isEmpty) throw Exception('No valid entries found in CSV');

      setState(() {
        _entries = entries;
        _current = 0;
        _added = 0;
        _skipped = 0;
        _done = false;
        _loading = false;
      });
    } catch (e) {
      setState(() { _parseError = e.toString(); _loading = false; });
    }
  }

  Future<void> _addEntry(_CsvEntry entry) async {
    final key = VaultSession.instance.key;
    final db = DatabaseService.instance;
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
  }

  Future<void> _handleAdd() async {
    await _addEntry(_entries[_current]);
    setState(() {
      _added++;
      _advance();
    });
  }

  void _handleSkip() {
    setState(() {
      _skipped++;
      _advance();
    });
  }

  void _advance() {
    if (_current + 1 >= _entries.length) {
      _done = true;
    } else {
      _current++;
    }
  }

  Future<void> _addAll() async {
    setState(() => _addingAll = true);
    for (int i = _current; i < _entries.length; i++) {
      await _addEntry(_entries[i]);
      _added++;
    }
    setState(() { _done = true; _addingAll = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Chrome')),
      body: _entries.isEmpty ? _buildPicker() : (_done ? _buildDone() : _buildReview()),
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
            child: const Icon(Icons.upload_file_outlined, color: AppColors.emerald, size: 28),
          ),
          const SizedBox(height: 20),
          const Text(
            'Import Chrome passwords',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Export from Chrome: Settings > Autofill > Passwords > Export.\nThen select the CSV file below.',
            style: TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_parseError!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            label: const Text('Select CSV file'),
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final entry = _entries[_current];
    final progress = (_current) / _entries.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_current + 1} of ${_entries.length}',
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
              const Spacer(),
              TextButton(
                onPressed: _addingAll ? null : _addAll,
                child: const Text('Add all remaining'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.emeraldSoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                if (entry.url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.url, style: const TextStyle(fontSize: 12, color: AppColors.inkMute), overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 16),
                _ImportField('Username', entry.username),
                const SizedBox(height: 10),
                _ImportField('Password', '••••••••••••'),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ImportField('Note', entry.note),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _addingAll ? null : _handleSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addingAll ? null : _handleAdd,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: _addingAll
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
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
              child: const Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Import complete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Text(
              '$_added added  •  $_skipped skipped',
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.settings.name == '/vault'),
              child: const Text('Back to vault'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportField extends StatelessWidget {
  final String label;
  final String value;
  const _ImportField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMute, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
        ),
      ],
    );
  }
}
