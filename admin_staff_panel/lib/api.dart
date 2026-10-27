import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the Python backend lives.
///
/// * `--dart-define=API_BASE=https://api.example.com` always wins.
/// * When the panel is served by the backend itself (`/panel/`), it talks to the same origin.
/// * Otherwise (e.g. `flutter run -d chrome`) it uses the local dev server.
String resolveApiBase() {
  const fromDefine = String.fromEnvironment('API_BASE');
  if (fromDefine.isNotEmpty) return fromDefine.replaceAll(RegExp(r'/+$'), '');
  if (kIsWeb && Uri.base.path.startsWith('/panel')) return Uri.base.origin;
  return 'https://tap-mg2.onrender.com';
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Turns FastAPI error bodies into one readable sentence.
String errorMessage(String body, String fallback) {
  try {
    final data = jsonDecode(body);
    final detail = data is Map ? data['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      return detail.map((e) => e is Map ? (e['msg'] ?? '').toString() : e.toString()).join(', ');
    }
  } catch (_) {}
  return fallback;
}

/// Thin JSON client for `/api/v1` with bearer tokens and one automatic refresh on 401.
class ApiClient {
  ApiClient({String? base, http.Client? client, this.storage})
      : base = base ?? resolveApiBase(),
        _http = client ?? http.Client();

  final String base;
  final http.Client _http;
  final TokenStorage? storage;

  String? accessToken;
  String? refreshToken;
  Future<void>? _refreshing;

  /// Called when the session can no longer be renewed (refresh token expired or revoked).
  VoidCallback? onSessionExpired;

  String get apiRoot => '$base/api/v1';
  bool get hasSession => accessToken != null;

  Future<void> restore() async {
    final s = storage;
    if (s == null) return;
    final t = await s.read();
    accessToken = t.$1;
    refreshToken = t.$2;
  }

  Future<void> setTokens(Map<String, dynamic> tokens) async {
    accessToken = tokens['access_token'] as String?;
    refreshToken = tokens['refresh_token'] as String?;
    await storage?.write(accessToken, refreshToken);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await storage?.clear();
  }

  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<http.Response> _send(String method, String path, Object? body) {
    final uri = Uri.parse('$apiRoot$path');
    final req = http.Request(method, uri)..headers.addAll(_headers(json: body != null));
    if (body != null) req.body = jsonEncode(body);
    return _http.send(req).then(http.Response.fromStream).timeout(const Duration(seconds: 30));
  }

  Future<http.Response> _request(String method, String path, Object? body) async {
    http.Response res;
    try {
      res = await _send(method, path, body);
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Check that it is running.');
    } catch (_) {
      throw ApiException('Cannot reach the server at $base. Is the backend running?');
    }
    if (res.statusCode == 401 && refreshToken != null && !path.startsWith('/auth/')) {
      await _renew();
      res = await _send(method, path, body);
    }
    return res;
  }

  Future<void> _renew() {
    return _refreshing ??= () async {
      try {
        final res = await _http.post(Uri.parse('$apiRoot/auth/refresh'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refreshToken}));
        if (res.statusCode != 200) {
          await clear();
          onSessionExpired?.call();
          throw ApiException('Your session has expired. Please sign in again.', 401);
        }
        await setTokens(jsonDecode(res.body) as Map<String, dynamic>);
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<dynamic> _json(String method, String path, [Object? body]) async {
    final res = await _request(method, path, body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(errorMessage(res.body, 'Request failed (${res.statusCode})'), res.statusCode);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<dynamic> get(String path) => _json('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _json('POST', path, body);
  Future<dynamic> patch(String path, Object body) => _json('PATCH', path, body);

  /// Raw bytes for authenticated images and CSV downloads.
  Future<Uint8List> bytes(String path) async {
    final res = await _request('GET', path, null);
    if (res.statusCode != 200) {
      throw ApiException(errorMessage(res.body, 'Download failed (${res.statusCode})'), res.statusCode);
    }
    return res.bodyBytes;
  }

  /// Public, unauthenticated health check on the server root.
  Future<bool> health() async {
    try {
      final res = await _http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      return data is Map && data['database'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ---------------- auth ----------------

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    return data;
  }

  Future<void> logout() async {
    final rt = refreshToken;
    if (rt != null) {
      try {
        await post('/auth/logout', {'refresh_token': rt});
      } catch (_) {
        // Signing out locally still matters even if the server is unreachable.
      }
    }
    await clear();
  }

  Uri staffSocketUri() {
    final ws = apiRoot.replaceFirst(RegExp(r'^http'), 'ws');
    return Uri.parse('$ws/ws/staff?token=${Uri.encodeQueryComponent(accessToken ?? '')}');
  }
}

/// Persists tokens so a page reload keeps the user signed in.
class TokenStorage {
  static const _a = 'rk_panel_access';
  static const _r = 'rk_panel_refresh';

  Future<(String?, String?)> read() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_a), p.getString(_r));
  }

  Future<void> write(String? access, String? refresh) async {
    final p = await SharedPreferences.getInstance();
    if (access != null) await p.setString(_a, access);
    if (refresh != null) await p.setString(_r, refresh);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_a);
    await p.remove(_r);
  }
}
