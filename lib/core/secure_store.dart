import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android Keystore / iOS Keychain backed storage for auth tokens.
///
/// Non-secret prefs (emails, UI flags) stay in SharedPreferences.
abstract final class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const sessionKey = 'secure_trade_session_v1';
  static const portalKey = 'secure_user_portal_v1';

  static Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) => _storage.read(key: key);

  static Future<void> delete(String key) => _storage.delete(key: key);

  static Future<void> deleteAllAuth() async {
    await Future.wait([
      _storage.delete(key: sessionKey),
      _storage.delete(key: portalKey),
    ]);
  }

  /// One-time move of legacy SharedPreferences token blobs → secure storage.
  static Future<void> migrateFromPrefsIfNeeded({
    required String legacySessionKey,
    required String legacyPortalKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(legacySessionKey);
    if (session != null && session.isNotEmpty) {
      final existing = await read(sessionKey);
      if (existing == null || existing.isEmpty) {
        await write(sessionKey, session);
      }
      await prefs.remove(legacySessionKey);
    }
    final portal = prefs.getString(legacyPortalKey);
    if (portal != null && portal.isNotEmpty) {
      final existing = await read(portalKey);
      if (existing == null || existing.isEmpty) {
        await write(portalKey, portal);
      }
      await prefs.remove(legacyPortalKey);
    }
  }
}
