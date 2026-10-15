// Named params can't be private, so prefer_initializing_formals can't apply here.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../data/api/api_client.dart';
import '../../data/api/auth_dto.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/token_store.dart';

enum AuthStatus { signedOut, signedIn }

/// Session state for the app; the router listens to it to guard routes.
class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository, required TokenStore tokens})
      : _repository = repository,
        _tokens = tokens;

  final AuthRepository _repository;
  final TokenStore _tokens;

  AuthStatus _status = AuthStatus.signedOut;
  UserDto? _user;
  String? _token;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  UserDto? get user => _user;
  String? get token => _token;

  /// Restores a stored session. A token the backend rejects (401) is discarded;
  /// if the backend is unreachable the user starts signed out but the token is kept.
  Future<void> restore() async {
    final token = _tokens.read();
    if (token == null) return;
    try {
      _signIn(token, await _repository.me(token));
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _tokens.clear();
    }
  }

  Future<void> login({required String email, required String password}) async =>
      _adopt(await _repository.login(email: email, password: password));

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      _adopt(await _repository.register(
          email: email, password: password, displayName: displayName));

  Future<void> logout() async {
    await _tokens.clear();
    _token = null;
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _adopt(AuthSession session) async {
    await _tokens.write(session.accessToken);
    _signIn(session.accessToken, session.user);
  }

  void _signIn(String token, UserDto user) {
    _token = token;
    _user = user;
    _status = AuthStatus.signedIn;
    notifyListeners();
  }
}
