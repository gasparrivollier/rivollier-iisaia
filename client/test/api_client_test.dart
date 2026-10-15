import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvoty/data/api/api_client.dart';

ApiClient _client(MockClientHandler handler, {void Function()? onUnauthorized}) => ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient(handler),
      onUnauthorized: onUnauthorized,
    );

Future<Map<String, dynamic>> _upload(ApiClient c, {String? token}) => c.postMultipart(
      '/identify',
      field: 'image',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'leaf.png',
      token: token,
    );

void main() {
  test('postMultipart sends the file under the field name with the bearer token', () async {
    late http.Request sent;
    final c = _client((req) async {
      sent = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final json = await _upload(c, token: 'a.b.c');

    expect(json, {'ok': true});
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/identify');
    expect(sent.headers['Authorization'], 'Bearer a.b.c');
    expect(sent.headers['content-type'], startsWith('multipart/form-data'));
    expect(sent.body, contains('name="image"'));
    expect(sent.body, contains('filename="leaf.png"'));
  });

  test('a 401 on an authenticated call fires onUnauthorized once and still throws', () async {
    var fired = 0;
    final c = _client((_) async => http.Response('{"detail":"Not authenticated"}', 401),
        onUnauthorized: () => fired++);

    await expectLater(_upload(c, token: 't'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(fired, 1);
  });

  test('a 401 without a token (e.g. wrong password) does not fire onUnauthorized', () async {
    var fired = 0;
    final c = _client((_) async => http.Response('{"detail":"Invalid email or password"}', 401),
        onUnauthorized: () => fired++);

    await expectLater(
        c.postJson('/auth/login', {'email': 'a', 'password': 'b'}), throwsA(isA<ApiException>()));
    expect(fired, 0);
  });

  test('a 429 exposes the Retry-After header', () async {
    final c = _client((_) async => http.Response(
        '{"detail":"Daily identification limit reached"}', 429,
        headers: {'retry-after': 'Wed, 15 Oct 2026 00:00:00 GMT'}));

    await expectLater(
      _upload(c, token: 't'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 429)
          .having((e) => e.retryAfter, 'retryAfter', 'Wed, 15 Oct 2026 00:00:00 GMT')),
    );
  });

  test('a per-call timeout turns into ApiException(0)', () async {
    final c = _client(
        (_) => Future.delayed(const Duration(milliseconds: 200), () => http.Response('{}', 200)));

    await expectLater(
      c.postMultipart('/identify',
          field: 'image',
          bytes: Uint8List(1),
          filename: 'a.png',
          timeout: const Duration(milliseconds: 20)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0)),
    );
  });
}
