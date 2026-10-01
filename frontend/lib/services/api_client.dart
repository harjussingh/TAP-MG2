import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

/// Thrown when the server rejects a request.
///
/// 401 and 403 mean different things and the app treats them differently: a
/// 401 means the session expired and logging in again fixes it, a 403 means
/// the role lacks the permission and logging in again would not.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthenticated => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;      // sold out, invalid transition
  bool get isValidation => statusCode == 422;    // broke a min/max rule
  bool get isRateLimited => statusCode == 429;
  bool get isNetwork => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The only place that talks HTTP.
///
/// Attaches the right headers per request, and handles refresh-token rotation
/// on a 401. The backend rotates refresh tokens, so every refresh returns a
/// new pair and the old one is dead; replaying an old one logs the user out
/// everywhere. That is why the new pair is always saved.
class ApiClient {
  ApiClient({required TokenStore store, http.Client? client})
      : _store = store,
        _client = client ?? http.Client();

  final TokenStore _store;
  final http.Client _client;

  Future<void>? _refreshing;

  Map<String, String> _headers({String? orderId, bool json = false}) {
    final access = _store.accessToken;
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Always sent: it is how the server finds a guest's cart.
      'X-Session-Id': _store.sessionId,
      if (access != null) 'Authorization': 'Bearer $access',
      if (orderId != null && _store.orderToken(orderId) != null)
        'X-Order-Token': _store.orderToken(orderId)!,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = <String, dynamic>{};
    query?.forEach((k, v) {
      if (v == null) return;
      cleaned[k] = v is List ? v.map((e) => '$e').toList() : '$v';
    });
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: cleaned.isEmpty ? null : cleaned);
  }

  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, String? orderId}) =>
      _send(() => _client.get(_uri(path, query),
          headers: _headers(orderId: orderId)), path, query, orderId);

  Future<dynamic> post(String path,
          {Object? body, Map<String, dynamic>? query, String? orderId}) =>
      _send(
          () => _client.post(_uri(path, query),
              headers: _headers(orderId: orderId, json: true),
              body: body == null ? null : jsonEncode(body)),
          path,
          query,
          orderId);

  Future<dynamic> patch(String path, {Object? body, String? orderId}) => _send(
      () => _client.patch(_uri(path),
          headers: _headers(orderId: orderId, json: true),
          body: body == null ? null : jsonEncode(body)),
      path,
      null,
      orderId);

  Future<dynamic> put(String path, {Object? body}) => _send(
      () => _client.put(_uri(path),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body)),
      path,
      null,
      null);

  Future<dynamic> delete(String path, {String? orderId}) => _send(
      () => _client.delete(_uri(path), headers: _headers(orderId: orderId)),
      path,
      null,
      orderId);

  Future<dynamic> _send(
    Future<http.Response> Function() request,
    String path,
    Map<String, dynamic>? query,
    String? orderId, {
    bool allowRetry = true,
  }) async {
    late final http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } catch (_) {
      throw ApiException(
          0,
          "We couldn't reach the kitchen. Check your connection and "
          'try again.');
    }

    // Session expired: rotate the tokens once, then repeat the request.
    if (response.statusCode == 401 &&
        allowRetry &&
        _store.refreshToken != null) {
      try {
        await _refreshTokens();
        return _send(request, path, query, orderId, allowRetry: false);
      } on ApiException {
        await _store.clearTokens();
      }
    }

    if (response.statusCode == 204 || response.body.isEmpty) return null;

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(response.statusCode, _detail(decoded, response));
  }

  Future<void> _refreshTokens() {
    // Share one refresh between parallel 401s rather than rotating twice.
    return _refreshing ??= () async {
      try {
        final res = await _client
            .post(_uri('/auth/refresh'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'refresh_token': _store.refreshToken}))
            .timeout(ApiConfig.timeout);

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw ApiException(res.statusCode, 'Session expired');
        }
        final json = _decode(res.body) as Map<String, dynamic>;
        await _store.saveTokens(
            json['access_token'] as String?, json['refresh_token'] as String?);
      } finally {
        _refreshing = null;
      }
    }();
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// The backend returns `{"detail": "..."}`, and for validation errors a list
  /// of `{loc, msg, type}`. Both are turned into something showable.
  String _detail(dynamic decoded, http.Response response) {
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((e) => e is Map ? (e['msg']?.toString() ?? '') : '$e')
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
    }
    switch (response.statusCode) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'Your account does not have access to that.';
      case 423:
        return 'Too many attempts. Try again in a few minutes.';
      case 429:
        return 'Slow down a moment and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void dispose() => _client.close();
}
