import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';
import 'database_service.dart';

class VaultSession extends ChangeNotifier {
  static final VaultSession instance = VaultSession._();

  /// Set true before opening system pickers/overlays that trigger paused state.
  /// Reset to false after the picker returns.
  static bool suppressLock = false;

  VaultSession._();

  SecretKey? _key;
  Timer? _autoLockTimer;
  bool _isLocked = true;

  bool get isLocked => _isLocked;
  bool get isUnlocked => !_isLocked && _key != null;

  SecretKey get key {
    if (_key == null) throw StateError('Vault is locked');
    return _key!;
  }

  final _encryption = EncryptionService();

  Future<bool> unlock(String password) async {
    final db = DatabaseService.instance;
    final saltB64 = await db.getMeta('kdf_salt');
    final cipherB64 = await db.getMeta('verifier_ciphertext');
    final nonceB64 = await db.getMeta('verifier_nonce');
    final macB64 = await db.getMeta('verifier_mac');

    if (saltB64 == null || cipherB64 == null || nonceB64 == null || macB64 == null) {
      return false;
    }

    final salt = base64Decode(saltB64);
    final kdfVersion = await db.getMeta('kdf_version') ?? 'argon2id_v1';
    final isPinVault = kdfVersion == 'argon2id_pin_v1';
    final derivedKey = await _encryption.deriveKey(
      password,
      salt,
      memory: isPinVault ? 16384 : 65536,
      iterations: isPinVault ? 2 : 3,
    );

    final result = EncryptionResult(
      ciphertext: base64Decode(cipherB64),
      nonce: base64Decode(nonceB64),
      mac: base64Decode(macB64),
    );

    final plaintext = await _encryption.decrypt(result, derivedKey);
    if (plaintext != EncryptionService.verifierPlaintext) {
      return false;
    }

    _key = derivedKey;
    _isLocked = false;
    _startAutoLock();
    notifyListeners();
    return true;
  }

  void unlockWithKey(SecretKey key) {
    _key = key;
    _isLocked = false;
    _startAutoLock();
    notifyListeners();
  }

  void lock() {
    _key = null;
    _isLocked = true;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    notifyListeners();
  }

  void resetAutoLockTimer() {
    _autoLockTimer?.cancel();
    _startAutoLock();
  }

  Future<void> _startAutoLock() async {
    _autoLockTimer?.cancel();
    final db = DatabaseService.instance;
    final minutesStr = await db.getMeta('auto_lock_minutes') ?? '5';
    final minutes = int.tryParse(minutesStr) ?? 5;
    _autoLockTimer = Timer(Duration(minutes: minutes), lock);
  }
}
