import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/repositories/auth_repository.dart';

const _authJson = {
  'access_token': 'a.b.c',
  'token_type': 'bearer',
  'user': {'id': 7, 'email': 'pat@example.com', 'display_name': 'Pat'},
};

HttpAuthRepository _repo(MockClientHandler handler) => HttpAuthRepository(
      ApiClient(baseUrl: 'http://api.test', httpClient: MockClient(handler)),
    );

void main() {
  test('register posts snake_case JSON and parses the session', () async {
    late http.Request sent;
    final repo = _repo((req) async {
      sent = req;
      return http.Response(jsonEncode(_authJson), 201);
    });

    final session =
        await repo.register(email: 'pat@example.com', password: 'pw-12345', displayName: 'Pat');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/auth/register');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body),
        {'email': 'pat@example.com', 'password': 'pw-12345', 'display_name': 'Pat'});
    expect(session.accessToken, 'a.b.c');
    expect(session.user.displayName, 'Pat');
    expect(session.user.id, 7);
  });

  test('me sends the bearer token', () async {
    late http.Request sent;
    final repo = _repo((req) async {
      sent = req;
      return http.Response(jsonEncode(_authJson['user']), 200);
    });

    final user = await repo.me('a.b.c');

    expect(sent.url.path, '/auth/me');
    expect(sent.headers['Authorization'], 'Bearer a.b.c');
    expect(user.email, 'pat@example.com');
  });

  test('non-2xx becomes ApiException with the backend detail', () async {
    final repo = _repo((_) async => http.Response('{"detail":"Not authenticated"}', 401));
    await expectLater(
      repo.me('bad'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'Not authenticated')),
    );
  });

  test('network failure becomes ApiException(0)', () async {
    final repo = _repo((_) async => throw http.ClientException('connection refused'));
    await expectLater(
      repo.login(email: 'a@example.com', password: 'x'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('a hung backend times out as ApiException(0)', () async {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      timeout: const Duration(milliseconds: 50),
      httpClient: MockClient((_) => Future.delayed(const Duration(seconds: 5), () => http.Response('', 200))),
    );
    await expectLater(
      HttpAuthRepository(api).me('t'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('a 200 with a non-JSON body becomes ApiException', () async {
    final repo = _repo((_) async => http.Response('<html>portal</html>', 200));
    await expectLater(
      repo.me('t'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)),
    );
  });

  test('a 200 with a non-object JSON body becomes ApiException', () async {
    final repo = _repo((_) async => http.Response('[1,2]', 200));
    await expectLater(
      repo.me('t'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)),
    );
  });

  test('a 200 with the wrong shape becomes ApiException', () async {
    final repo = _repo((_) async => http.Response(
        jsonEncode({'token_type': 'bearer', 'user': _authJson['user']}), 200));
    await expectLater(
      repo.login(email: 'a@example.com', password: 'x'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)),
    );
  });
}
