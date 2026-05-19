import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PasswordEntry {
  final int? id;
  final String siteName;
  final String username;
  final String? url;
  final Uint8List passwordEncrypted;
  final Uint8List passwordNonce;
  final Uint8List passwordMac;
  final Uint8List? notesEncrypted;
  final Uint8List? notesNonce;
  final Uint8List? notesMac;
  final int createdAt;
  final int updatedAt;

  const PasswordEntry({
    this.id,
    required this.siteName,
    required this.username,
    this.url,
    required this.passwordEncrypted,
    required this.passwordNonce,
    required this.passwordMac,
    this.notesEncrypted,
    this.notesNonce,
    this.notesMac,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PasswordEntry.fromMap(Map<String, dynamic> m) {
    return PasswordEntry(
      id: m['id'] as int,
      siteName: m['site_name'] as String,
      username: m['username'] as String,
      url: m['url'] as String?,
      passwordEncrypted: m['password_encrypted'] as Uint8List,
      passwordNonce: m['password_nonce'] as Uint8List,
      passwordMac: m['password_mac'] as Uint8List,
      notesEncrypted: m['notes_encrypted'] as Uint8List?,
      notesNonce: m['notes_nonce'] as Uint8List?,
      notesMac: m['notes_mac'] as Uint8List?,
      createdAt: m['created_at'] as int,
      updatedAt: m['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'site_name': siteName,
      'username': username,
      'url': url,
      'password_encrypted': passwordEncrypted,
      'password_nonce': passwordNonce,
      'password_mac': passwordMac,
      'notes_encrypted': notesEncrypted,
      'notes_nonce': notesNonce,
      'notes_mac': notesMac,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  PasswordEntry copyWith({
    int? id,
    String? siteName,
    String? username,
    String? url,
    Uint8List? passwordEncrypted,
    Uint8List? passwordNonce,
    Uint8List? passwordMac,
    Uint8List? notesEncrypted,
    Uint8List? notesNonce,
    Uint8List? notesMac,
    int? updatedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      siteName: siteName ?? this.siteName,
      username: username ?? this.username,
      url: url ?? this.url,
      passwordEncrypted: passwordEncrypted ?? this.passwordEncrypted,
      passwordNonce: passwordNonce ?? this.passwordNonce,
      passwordMac: passwordMac ?? this.passwordMac,
      notesEncrypted: notesEncrypted ?? this.notesEncrypted,
      notesNonce: notesNonce ?? this.notesNonce,
      notesMac: notesMac ?? this.notesMac,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PasswordHistoryEntry {
  final int? id;
  final int passwordEntryId;
  final Uint8List oldPasswordEncrypted;
  final Uint8List oldPasswordNonce;
  final Uint8List oldPasswordMac;
  final int changedAt;

  const PasswordHistoryEntry({
    this.id,
    required this.passwordEntryId,
    required this.oldPasswordEncrypted,
    required this.oldPasswordNonce,
    required this.oldPasswordMac,
    required this.changedAt,
  });

  factory PasswordHistoryEntry.fromMap(Map<String, dynamic> m) {
    return PasswordHistoryEntry(
      id: m['id'] as int,
      passwordEntryId: m['password_entry_id'] as int,
      oldPasswordEncrypted: m['old_password_encrypted'] as Uint8List,
      oldPasswordNonce: m['old_password_nonce'] as Uint8List,
      oldPasswordMac: m['old_password_mac'] as Uint8List,
      changedAt: m['changed_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'password_entry_id': passwordEntryId,
      'old_password_encrypted': oldPasswordEncrypted,
      'old_password_nonce': oldPasswordNonce,
      'old_password_mac': oldPasswordMac,
      'changed_at': changedAt,
    };
  }
}

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'passmgr.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE passwords (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        site_name             TEXT    NOT NULL,
        username              TEXT    NOT NULL,
        url                   TEXT,
        password_encrypted    BLOB    NOT NULL,
        password_nonce        BLOB    NOT NULL,
        password_mac          BLOB    NOT NULL,
        notes_encrypted       BLOB,
        notes_nonce           BLOB,
        notes_mac             BLOB,
        created_at            INTEGER NOT NULL,
        updated_at            INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE password_history (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        password_entry_id        INTEGER NOT NULL,
        old_password_encrypted   BLOB    NOT NULL,
        old_password_nonce       BLOB    NOT NULL,
        old_password_mac         BLOB    NOT NULL,
        changed_at               INTEGER NOT NULL,
        FOREIGN KEY (password_entry_id) REFERENCES passwords(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // app_meta

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isVaultInitialized() async {
    final salt = await getMeta('kdf_salt');
    return salt != null;
  }

  // passwords CRUD

  Future<List<PasswordEntry>> getAllEntries() async {
    final db = await database;
    final rows = await db.query('passwords', orderBy: 'site_name COLLATE NOCASE ASC');
    return rows.map(PasswordEntry.fromMap).toList();
  }

  Future<List<PasswordEntry>> searchEntries(String query) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final rows = await db.query(
      'passwords',
      where: 'LOWER(site_name) LIKE ? OR LOWER(username) LIKE ?',
      whereArgs: [q, q],
      orderBy: 'site_name COLLATE NOCASE ASC',
    );
    return rows.map(PasswordEntry.fromMap).toList();
  }

  Future<PasswordEntry?> getEntry(int id) async {
    final db = await database;
    final rows = await db.query('passwords', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PasswordEntry.fromMap(rows.first);
  }

  Future<int> insertEntry(PasswordEntry entry) async {
    final db = await database;
    return db.insert('passwords', entry.toMap());
  }

  Future<void> updateEntry(PasswordEntry entry, {bool archiveOldPassword = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (archiveOldPassword) {
        final existing = await txn.query(
          'passwords',
          columns: ['password_encrypted', 'password_nonce', 'password_mac', 'updated_at'],
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        if (existing.isNotEmpty) {
          await txn.insert('password_history', {
            'password_entry_id': entry.id,
            'old_password_encrypted': existing.first['password_encrypted'],
            'old_password_nonce': existing.first['password_nonce'],
            'old_password_mac': existing.first['password_mac'],
            'changed_at': existing.first['updated_at'],
          });
        }
      }
      await txn.update(
        'passwords',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    });
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('passwords', where: 'id = ?', whereArgs: [id]);
  }

  // history

  Future<List<PasswordHistoryEntry>> getHistory(int entryId) async {
    final db = await database;
    final rows = await db.query(
      'password_history',
      where: 'password_entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(PasswordHistoryEntry.fromMap).toList();
  }

  // re-encryption on master password change
  Future<void> reEncryptAll({
    required Future<Uint8List> Function(Uint8List cipher, Uint8List nonce, Uint8List mac) decryptBlob,
    required Future<Map<String, Uint8List>> Function(Uint8List plaintext) encryptBlob,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final entries = await txn.query('passwords');
      for (final row in entries) {
        final decPass = await decryptBlob(
          row['password_encrypted'] as Uint8List,
          row['password_nonce'] as Uint8List,
          row['password_mac'] as Uint8List,
        );
        final encPass = await encryptBlob(decPass);

        Map<String, dynamic> update = {
          'password_encrypted': encPass['ciphertext'],
          'password_nonce': encPass['nonce'],
          'password_mac': encPass['mac'],
        };

        if (row['notes_encrypted'] != null) {
          final decNotes = await decryptBlob(
            row['notes_encrypted'] as Uint8List,
            row['notes_nonce'] as Uint8List,
            row['notes_mac'] as Uint8List,
          );
          final encNotes = await encryptBlob(decNotes);
          update['notes_encrypted'] = encNotes['ciphertext'];
          update['notes_nonce'] = encNotes['nonce'];
          update['notes_mac'] = encNotes['mac'];
        }

        await txn.update('passwords', update, where: 'id = ?', whereArgs: [row['id']]);
      }

      final history = await txn.query('password_history');
      for (final row in history) {
        final dec = await decryptBlob(
          row['old_password_encrypted'] as Uint8List,
          row['old_password_nonce'] as Uint8List,
          row['old_password_mac'] as Uint8List,
        );
        final enc = await encryptBlob(dec);
        await txn.update(
          'password_history',
          {
            'old_password_encrypted': enc['ciphertext'],
            'old_password_nonce': enc['nonce'],
            'old_password_mac': enc['mac'],
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }
}
