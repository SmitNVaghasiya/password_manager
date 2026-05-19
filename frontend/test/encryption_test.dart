import 'package:flutter_test/flutter_test.dart';
import 'package:passmgr/services/encryption_service.dart';

void main() {
  final enc = EncryptionService();

  group('PBKDF2 key derivation', () {
    test('same password + salt produces same key bytes', () async {
      final salt = enc.generateSalt();
      final key1 = await enc.deriveKey('MyPassword123!', salt);
      final key2 = await enc.deriveKey('MyPassword123!', salt);
      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      expect(bytes1, equals(bytes2));
    });

    test('different password produces different key', () async {
      final salt = enc.generateSalt();
      final key1 = await enc.deriveKey('Password1', salt);
      final key2 = await enc.deriveKey('Password2', salt);
      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      expect(bytes1, isNot(equals(bytes2)));
    });

    test('different salt produces different key', () async {
      final salt1 = enc.generateSalt();
      final salt2 = enc.generateSalt();
      final key1 = await enc.deriveKey('SamePassword', salt1);
      final key2 = await enc.deriveKey('SamePassword', salt2);
      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      expect(bytes1, isNot(equals(bytes2)));
    });
  });

  group('AES-GCM encrypt/decrypt roundtrip', () {
    test('roundtrip 50 times with different nonces', () async {
      final salt = enc.generateSalt();
      final key = await enc.deriveKey('TestPassword!', salt);

      for (var i = 0; i < 50; i++) {
        final plaintext = 'my secret password $i';
        final result = await enc.encrypt(plaintext, key);
        final decrypted = await enc.decrypt(result, key);
        expect(decrypted, equals(plaintext));
      }
    });

    test('different nonce produced per call', () async {
      final salt = enc.generateSalt();
      final key = await enc.deriveKey('TestPassword!', salt);

      final r1 = await enc.encrypt('same plaintext', key);
      final r2 = await enc.encrypt('same plaintext', key);
      expect(r1.nonce, isNot(equals(r2.nonce)));
    });

    test('wrong key fails decryption — returns null, not silent corruption', () async {
      final salt = enc.generateSalt();
      final rightKey = await enc.deriveKey('RightPassword', salt);
      final wrongKey = await enc.deriveKey('WrongPassword', salt);

      final result = await enc.encrypt('secret', rightKey);
      final decrypted = await enc.decrypt(result, wrongKey);
      expect(decrypted, isNull);
    });

    test('verifier roundtrip matches constant', () async {
      final salt = enc.generateSalt();
      final key = await enc.deriveKey('VaultPassword1!', salt);

      final result = await enc.encrypt(EncryptionService.verifierPlaintext, key);
      final decrypted = await enc.decrypt(result, key);
      expect(decrypted, equals(EncryptionService.verifierPlaintext));
    });
  });

  group('Password generator', () {
    test('default length 16', () {
      final pw = enc.generatePassword();
      expect(pw.length, equals(16));
    });

    test('custom length respected', () {
      for (final len in [8, 12, 24, 32]) {
        final pw = enc.generatePassword(length: len);
        expect(pw.length, equals(len));
      }
    });

    test('uppercase only constraint', () {
      final pw = enc.generatePassword(
        length: 20,
        uppercase: true,
        lowercase: false,
        numbers: false,
        symbols: false,
      );
      expect(pw.contains(RegExp(r'[A-Z]')), isTrue);
      expect(pw.contains(RegExp(r'[a-z]')), isFalse);
      expect(pw.contains(RegExp(r'[0-9]')), isFalse);
    });

    test('contains at least one char from each enabled set', () {
      for (var i = 0; i < 20; i++) {
        final pw = enc.generatePassword(
          length: 16,
          uppercase: true,
          lowercase: true,
          numbers: true,
          symbols: true,
        );
        expect(pw.contains(RegExp(r'[A-Z]')), isTrue);
        expect(pw.contains(RegExp(r'[a-z]')), isTrue);
        expect(pw.contains(RegExp(r'[0-9]')), isTrue);
      }
    });

    test('no two consecutive calls same output', () {
      final pw1 = enc.generatePassword();
      final pw2 = enc.generatePassword();
      // Extremely unlikely to be equal; treat as deterministic failure if so
      expect(pw1, isNot(equals(pw2)));
    });
  });
}
