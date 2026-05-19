import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'encryption_service.dart';
import 'database_service.dart';
import 'vault_session.dart';

class BackupService {
  final _encryption = EncryptionService();

  Future<void> exportBackup() async {
    final db = DatabaseService.instance;
    final key = VaultSession.instance.key;

    final entries = await db.getAllEntries();
    final List<Map<String, dynamic>> exportData = [];

    for (final entry in entries) {
      final history = await db.getHistory(entry.id!);

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

      final List<Map<String, dynamic>> historyData = [];
      for (final h in history) {
        final oldPass = await _encryption.decrypt(
          EncryptionResult(
            ciphertext: h.oldPasswordEncrypted,
            nonce: h.oldPasswordNonce,
            mac: h.oldPasswordMac,
          ),
          key,
        );
        historyData.add({
          'password': oldPass,
          'changed_at': h.changedAt,
        });
      }

      exportData.add({
        'site_name': entry.siteName,
        'username': entry.username,
        'url': entry.url,
        'password': password,
        'notes': notes,
        'created_at': entry.createdAt,
        'updated_at': entry.updatedAt,
        'history': historyData,
      });
    }

    final jsonBytes = utf8.encode(jsonEncode(exportData));
    final plaintext = Uint8List.fromList(jsonBytes);

    final encrypted = await _encryption.encryptBytes(plaintext, key);

    // Format: [4 bytes nonce length][nonce][4 bytes mac length][mac][ciphertext]
    final nonce = encrypted.nonce;
    final mac = encrypted.mac;
    final cipher = encrypted.ciphertext;

    final buffer = BytesBuilder();
    buffer.addByte((nonce.length >> 24) & 0xFF);
    buffer.addByte((nonce.length >> 16) & 0xFF);
    buffer.addByte((nonce.length >> 8) & 0xFF);
    buffer.addByte(nonce.length & 0xFF);
    buffer.add(nonce);
    buffer.addByte((mac.length >> 24) & 0xFF);
    buffer.addByte((mac.length >> 16) & 0xFF);
    buffer.addByte((mac.length >> 8) & 0xFF);
    buffer.addByte(mac.length & 0xFF);
    buffer.add(mac);
    buffer.add(cipher);

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/passmgr_backup_$timestamp.enc');
    await file.writeAsBytes(buffer.toBytes());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PassMgr Encrypted Backup',
      text: 'PassMgr backup — requires your master password to restore.',
    );
  }

  Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) return 0;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();

    final key = VaultSession.instance.key;

    // Parse format
    int offset = 0;
    final nonceLen = (bytes[offset] << 24) | (bytes[offset+1] << 16) | (bytes[offset+2] << 8) | bytes[offset+3];
    offset += 4;
    final nonce = Uint8List.fromList(bytes.sublist(offset, offset + nonceLen));
    offset += nonceLen;
    final macLen = (bytes[offset] << 24) | (bytes[offset+1] << 16) | (bytes[offset+2] << 8) | bytes[offset+3];
    offset += 4;
    final mac = Uint8List.fromList(bytes.sublist(offset, offset + macLen));
    offset += macLen;
    final cipher = Uint8List.fromList(bytes.sublist(offset));

    final decrypted = await _encryption.decryptBytes(
      EncryptionResult(ciphertext: cipher, nonce: nonce, mac: mac),
      key,
    );
    if (decrypted == null) throw Exception('Decryption failed — wrong master password or corrupted backup.');

    final List<dynamic> data = jsonDecode(utf8.decode(decrypted));
    final db = DatabaseService.instance;
    int count = 0;

    for (final item in data) {
      final password = item['password'] as String? ?? '';
      final encPass = await _encryption.encrypt(password, key);

      EncryptionResult? encNotes;
      if (item['notes'] != null && (item['notes'] as String).isNotEmpty) {
        encNotes = await _encryption.encrypt(item['notes'] as String, key);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final entryId = await db.insertEntry(PasswordEntry(
        siteName: item['site_name'] as String? ?? '',
        username: item['username'] as String? ?? '',
        url: item['url'] as String?,
        passwordEncrypted: encPass.ciphertext,
        passwordNonce: encPass.nonce,
        passwordMac: encPass.mac,
        notesEncrypted: encNotes?.ciphertext,
        notesNonce: encNotes?.nonce,
        notesMac: encNotes?.mac,
        createdAt: item['created_at'] as int? ?? now,
        updatedAt: item['updated_at'] as int? ?? now,
      ));

      final historyList = item['history'] as List<dynamic>? ?? [];
      for (final h in historyList) {
        final oldPass = h['password'] as String? ?? '';
        final encOld = await _encryption.encrypt(oldPass, key);
        final dbRaw = await db.database;
        await dbRaw.insert('password_history', {
          'password_entry_id': entryId,
          'old_password_encrypted': encOld.ciphertext,
          'old_password_nonce': encOld.nonce,
          'old_password_mac': encOld.mac,
          'changed_at': h['changed_at'] as int? ?? now,
        });
      }
      count++;
    }

    return count;
  }
}
