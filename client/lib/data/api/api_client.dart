import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed call to the Yvoty backend. [statusCode] is the HTTP status, or 0 when
/// the backend could not be reached (network error or timeout).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.fieldErrors = const {}});

  final int statusCode;
  final String message;

  /// Per-field validation messages from a 422, keyed by the last `loc` element
  /// (e.g. 'email', 'password', 'display_name').
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON-over-HTTP client for the Yvoty backend. Paths and field names mirror
/// backend/openapi.json; test/api_contract_test.dart keeps the two in sync.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  Future<Map<String, dynamic>> postJson(String path, Map<String, Object?> body) => _send(
        () => _http.post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> getJson(String path, {String? token}) => _send(
        () => _http.get(
          _uri(path),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(timeout);
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    } on TimeoutException {
      throw ApiException(0, 'Timed out after ${timeout.inSeconds}s');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _detail(res.body), fieldErrors: _fieldErrors(res.body));
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(res.statusCode, _unexpected);
    } on TypeError {
      throw ApiException(res.statusCode, _unexpected);
    }
  }

  static const _unexpected = 'Unexpected response from server';

  static Map<String, String> _fieldErrors(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['detail'] is! List) return const {};
      final out = <String, String>{};
      for (final item in decoded['detail'] as List) {
        if (item is! Map || item['loc'] is! List || item['msg'] is! String) continue;
        final loc = item['loc'] as List;
        if (loc.isEmpty || loc.last is! String) continue;
        out.putIfAbsent(
            loc.last as String, () => (item['msg'] as String).replaceFirst('Value error, ', ''));
      }
      return out;
    } on FormatException {
      return const {};
    }
  }

  static String _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } on FormatException {
      // Not JSON (e.g. a proxy error page); fall back to the raw body.
    }
    return body;
  }
}
