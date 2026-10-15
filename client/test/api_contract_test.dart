// Guards the hand-written API client against backend drift: every path and JSON
// field name the client uses must exist in the committed backend/openapi.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final spec =
      jsonDecode(File('../backend/openapi.json').readAsStringSync()) as Map<String, dynamic>;
  final paths = spec['paths'] as Map<String, dynamic>;
  final schemas = spec['components']['schemas'] as Map<String, dynamic>;
  Iterable<String> props(String name) =>
      (schemas[name]['properties'] as Map<String, dynamic>).keys;

  test('auth endpoints the client calls exist with the right methods', () {
    expect(paths['/auth/register'], contains('post'));
    expect(paths['/auth/login'], contains('post'));
    expect(paths['/auth/me'], contains('get'));
  });

  test('request bodies accept the field names HttpAuthRepository sends', () {
    expect(props('RegisterRequest'), containsAll(['email', 'password', 'display_name']));
    expect(props('LoginRequest'), containsAll(['email', 'password']));
  });

  test('responses carry the field names the DTOs parse', () {
    expect(props('AuthResponse'), containsAll(['access_token', 'token_type', 'user']));
    expect(props('UserOut'), containsAll(['id', 'email', 'display_name']));
  });

  test('identify endpoint accepts a multipart image field and returns the parsed shape', () {
    expect(paths['/identify'], contains('post'));
    final bodyRef = paths['/identify']['post']['requestBody']['content']['multipart/form-data']
        ['schema']['\$ref'] as String;
    expect(props(bodyRef.split('/').last), contains('image'));
    expect(props('IdentifyResponse'),
        containsAll(['identification_id', 'remaining_requests', 'image', 'results']));
    expect(props('IdentifyImageOut'), containsAll(['url', 'predicted_organ']));
    expect(
        props('IdentifyResultOut'),
        containsAll(
            ['rank', 'score', 'scientific_name_without_author', 'family', 'common_names']));
  });
}
