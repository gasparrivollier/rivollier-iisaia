import 'package:shared_preferences/shared_preferences.dart';

/// Persists the access token. On web, shared_preferences keeps it in localStorage
/// as `flutter.auth_token` (JSON-encoded); e2e/support/auth.ts relies on that key.
class TokenStore {
  TokenStore(this._prefs);

  static const key = 'auth_token';

  final SharedPreferences _prefs;

  /// The stored token, or null if absent or not a string (tampered storage).
  String? read() {
    final value = _prefs.get(key);
    return value is String ? value : null;
  }

  Future<void> write(String token) => _prefs.setString(key, token);

  Future<void> clear() => _prefs.remove(key);
}
