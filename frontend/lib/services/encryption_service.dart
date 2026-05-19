import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionResult {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;

  const EncryptionResult({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });
}

class EncryptionService {
  static const _pbkdf2Iterations = 150000;
  static const _saltLength = 32;
  static const _nonceLength = 12;
  static const _keyLength = 32;
  static const String verifierPlaintext = 'VAULT_OK_v1';

  final _aesGcm = AesGcm.with256bits(nonceLength: _nonceLength);
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: _keyLength * 8,
  );

  Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
  }

  Uint8List generateNonce() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_nonceLength, (_) => rng.nextInt(256)));
  }

  Future<SecretKey> deriveKey(String password, Uint8List salt) async {
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(password.codeUnits),
      nonce: salt,
    );
    return secretKey;
  }

  Future<EncryptionResult> encrypt(String plaintext, SecretKey key) async {
    final nonce = generateNonce();
    final secretBox = await _aesGcm.encrypt(
      plaintext.codeUnits,
      secretKey: key,
      nonce: nonce,
    );
    return EncryptionResult(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: nonce,
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<EncryptionResult> encryptBytes(Uint8List data, SecretKey key) async {
    final nonce = generateNonce();
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: key,
      nonce: nonce,
    );
    return EncryptionResult(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: nonce,
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<String?> decrypt(EncryptionResult result, SecretKey key) async {
    try {
      final secretBox = SecretBox(
        result.ciphertext,
        nonce: result.nonce,
        mac: Mac(result.mac),
      );
      final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return String.fromCharCodes(plainBytes);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> decryptBytes(EncryptionResult result, SecretKey key) async {
    try {
      final secretBox = SecretBox(
        result.ciphertext,
        nonce: result.nonce,
        mac: Mac(result.mac),
      );
      final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return Uint8List.fromList(plainBytes);
    } catch (_) {
      return null;
    }
  }

  String generatePassword({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    const syms = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    var charset = '';
    var required = <String>[];

    if (uppercase) { charset += upper; required.add(upper); }
    if (lowercase) { charset += lower; required.add(lower); }
    if (numbers)   { charset += nums;  required.add(nums); }
    if (symbols)   { charset += syms;  required.add(syms); }

    if (charset.isEmpty) charset = lower;

    final rng = Random.secure();
    final result = List<String>.generate(length, (_) => charset[rng.nextInt(charset.length)]);

    // Ensure at least one char from each required set
    for (var i = 0; i < required.length && i < length; i++) {
      final set = required[i];
      result[i] = set[rng.nextInt(set.length)];
    }

    // Shuffle to avoid predictable positions
    result.shuffle(rng);
    return result.join();
  }
}
