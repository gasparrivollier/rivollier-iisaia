import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A failed call to the Yvoty backend. [statusCode] is the HTTP status, or 0 when
/// the backend could not be reached (network error or timeout).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.fieldErrors = const {}, this.retryAfter});

  final int statusCode;
  final String message;

  /// Per-field validation messages from a 422, keyed by the last `loc` element
  /// (e.g. 'email', 'password', 'display_name').
  final Map<String, String> fieldErrors;

  /// Raw `Retry-After` response header (an HTTP date from Pl@ntNet), if the server sent one.
  final String? retryAfter;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// One file part of a multipart upload.
class UploadPart {
  const UploadPart({required this.field, required this.bytes, required this.filename});

  final String field;
  final Uint8List bytes;
  final String filename;
}

/// Thin JSON-over-HTTP client for the Yvoty backend. Paths and field names mirror
/// backend/openapi.json; test/api_contract_test.dart keeps the two in sync.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  /// Called when a request that carried a bearer token gets a 401 (session expired).
  final void Function()? onUnauthorized;

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
        authenticated: token != null,
      );

  /// Multipart POST. [fields] may repeat a key (MultipartRequest.fields is a Map and cannot),
  /// so each one is sent as a text part with no filename, which servers read as a form field.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<UploadPart> files,
    List<MapEntry<String, String>> fields = const [],
    String? token,
    Duration? timeout,
  }) =>
      _send(
        () async {
          final req = http.MultipartRequest('POST', _uri(path));
          for (final f in files) {
            req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename));
          }
          for (final f in fields) {
            req.files.add(http.MultipartFile.fromString(f.key, f.value));
          }
          if (token != null) req.headers['Authorization'] = 'Bearer $token';
          return http.Response.fromStream(await _http.send(req));
        },
        authenticated: token != null,
        timeout: timeout,
      );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    bool authenticated = false,
    Duration? timeout,
  }) async {
    final limit = timeout ?? this.timeout;
    final http.Response res;
    try {
      res = await request().timeout(limit);
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    } on TimeoutException {
      throw ApiException(0, 'Timed out after ${limit.inSeconds}s');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 401 && authenticated) onUnauthorized?.call();
      throw ApiException(
        res.statusCode,
        _detail(res.body),
        fieldErrors: _fieldErrors(res.body),
        retryAfter: res.headers['retry-after'],
      );
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
