import '../api/api_client.dart';
import '../api/auth_dto.dart';

/// Register/login/current-user against the backend's /auth endpoints.
abstract class AuthRepository {
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<UserDto> me(String token);
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);

  final ApiClient _api;

  /// Maps a 2xx body with the wrong shape (missing or mistyped field) to ApiException.
  static T _parse<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    try {
      return fromJson(json);
    } on TypeError {
      throw ApiException(200, 'Unexpected response from server');
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      _parse(
        await _api.postJson('/auth/register', {
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
        AuthSession.fromJson,
      );

  @override
  Future<AuthSession> login({required String email, required String password}) async =>
      _parse(
        await _api.postJson('/auth/login', {'email': email, 'password': password}),
        AuthSession.fromJson,
      );

  @override
  Future<UserDto> me(String token) async =>
      _parse(await _api.getJson('/auth/me', token: token), UserDto.fromJson);
}

/// In-memory double for widget tests; mirrors the backend's 401/409 behaviour.
class FakeAuthRepository implements AuthRepository {
  final Map<String, ({String password, UserDto user})> _byEmail = {};
  int _nextId = 1;

  static String tokenFor(UserDto user) => 'fake-token-${user.id}';

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final key = email.trim().toLowerCase();
    if (_byEmail.containsKey(key)) throw ApiException(409, 'Email already registered');
    final user = UserDto(id: _nextId++, email: key, displayName: displayName.trim());
    _byEmail[key] = (password: password, user: user);
    return AuthSession(accessToken: tokenFor(user), user: user);
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final entry = _byEmail[email.trim().toLowerCase()];
    if (entry == null || entry.password != password) {
      throw ApiException(401, 'Invalid email or password');
    }
    return AuthSession(accessToken: tokenFor(entry.user), user: entry.user);
  }

  @override
  Future<UserDto> me(String token) async {
    for (final entry in _byEmail.values) {
      if (tokenFor(entry.user) == token) return entry.user;
    }
    throw ApiException(401, 'Not authenticated');
  }
}
