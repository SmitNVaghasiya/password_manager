import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const _keyStorageKey = 'passmgr_vault_key';
  static const _biometricEnabledKey = 'passmgr_biometric_enabled';

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> storeKey(SecretKey key) async {
    final keyBytes = await key.extractBytes();
    final encoded = base64Encode(keyBytes);
    await _storage.write(key: _keyStorageKey, value: encoded);
    await _storage.write(key: _biometricEnabledKey, value: 'true');
  }

  Future<SecretKey?> authenticateAndGetKey() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock PassMgr with biometrics',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return null;

      final encoded = await _storage.read(key: _keyStorageKey);
      if (encoded == null) return null;

      final keyBytes = base64Decode(encoded);
      return SecretKey(keyBytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> disable() async {
    await _storage.delete(key: _keyStorageKey);
    await _storage.write(key: _biometricEnabledKey, value: 'false');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
