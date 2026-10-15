import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/api/auth_dto.dart';
import 'package:yvoty/data/repositories/auth_repository.dart';
import 'package:yvoty/data/token_store.dart';
import 'package:yvoty/features/auth/auth_controller.dart';

class _OfflineAuthRepository extends FakeAuthRepository {
  @override
  Future<UserDto> me(String token) async => throw ApiException(0, 'offline');
}

class _GarbledAuthRepository extends FakeAuthRepository {
  @override
  Future<UserDto> me(String token) async =>
      throw ApiException(200, 'Unexpected response from server');
}

Future<(AuthController, TokenStore)> _controller(
  AuthRepository repo, {
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final tokens = TokenStore(await SharedPreferences.getInstance());
  return (AuthController(repository: repo, tokens: tokens), tokens);
}

void main() {
  test('starts signed out with no stored token', () async {
    final (auth, _) = await _controller(FakeAuthRepository());
    await auth.restore();
    expect(auth.isSignedIn, isFalse);
  });

  test('register signs in and persists the token; logout clears it', () async {
    final (auth, tokens) = await _controller(FakeAuthRepository());
    var notified = 0;
    auth.addListener(() => notified++);

    await auth.register(email: 'pat@example.com', password: 'pw-12345', displayName: 'Pat');
    expect(auth.isSignedIn, isTrue);
    expect(auth.user!.displayName, 'Pat');
    expect(tokens.read(), auth.token);

    await auth.logout();
    expect(auth.isSignedIn, isFalse);
    expect(tokens.read(), isNull);
    expect(notified, 2);
  });

  test('restore signs in with a token the backend accepts', () async {
    final repo = FakeAuthRepository();
    final session =
        await repo.register(email: 'pat@example.com', password: 'pw-12345', displayName: 'Pat');
    final (auth, _) = await _controller(repo, stored: {TokenStore.key: session.accessToken});
    await auth.restore();
    expect(auth.isSignedIn, isTrue);
    expect(auth.user!.email, 'pat@example.com');
  });

  test('restore discards a token the backend rejects', () async {
    final (auth, tokens) =
        await _controller(FakeAuthRepository(), stored: {TokenStore.key: 'garbage'});
    await auth.restore();
    expect(auth.isSignedIn, isFalse);
    expect(tokens.read(), isNull);
  });

  test('restore keeps the token when the backend is unreachable', () async {
    final (auth, tokens) =
        await _controller(_OfflineAuthRepository(), stored: {TokenStore.key: 'kept'});
    await auth.restore();
    expect(auth.isSignedIn, isFalse);
    expect(tokens.read(), 'kept');
  });

  test('TokenStore.read ignores non-string values', () async {
    final (_, tokens) = await _controller(FakeAuthRepository(), stored: {TokenStore.key: 42});
    expect(tokens.read(), isNull);
  });

  test('failed login leaves the user signed out and rethrows', () async {
    final (auth, _) = await _controller(FakeAuthRepository());
    await expectLater(
      auth.login(email: 'nobody@example.com', password: 'pw-12345'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(auth.isSignedIn, isFalse);
  });

  test('restore survives a malformed backend response', () async {
    final (auth, _) =
        await _controller(_GarbledAuthRepository(), stored: {TokenStore.key: 't'});
    await auth.restore();
    expect(auth.isSignedIn, isFalse);
  });
}
