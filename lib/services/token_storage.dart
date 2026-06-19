import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'auth.access';
  static const _refreshKey = 'auth.refresh';
  static const _userKey = 'auth.user';

  final FlutterSecureStorage _storage;

  // Keystore can fail with PlatformException (bad padding, unwrap failure)
  // after reinstall or key corruption. Treat as missing rather than crashing.
  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      await _safeDeleteAll();
      return null;
    }
  }

  Future<void> _safeDeleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  Future<String?> readAccess() => _safeRead(_accessKey);
  Future<String?> readRefresh() => _safeRead(_refreshKey);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> saveAccess(String access) =>
      _storage.write(key: _accessKey, value: access);

  Future<void> saveUserJson(String json) =>
      _storage.write(key: _userKey, value: json);

  Future<String?> readUserJson() => _safeRead(_userKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }

  Future<bool> hasTokens() async {
    final a = await readAccess();
    final r = await readRefresh();
    return a != null && r != null;
  }
}
