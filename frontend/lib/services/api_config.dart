import 'package:flutter/foundation.dart';

/// Everything that changes between environments.
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('https://tap-mg2.onrender.com/api/v1');

  /// The backend is versioned, so the version is part of the base URL.
  ///
  /// On an Android emulator your laptop is not localhost: a server on port
  /// 8000 is reachable at 10.0.2.2. In a browser, on Windows and in the iOS
  /// simulator it is plain localhost. On a physical phone use the laptop's LAN
  /// address with both devices on the same Wi-Fi.
  ///
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://your-app.onrender.com/api/v1
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'https://tap-mg2.onrender.com/api/v1';
    }
    return 'https://tap-mg2.onrender.com/api/v1';
  }

  static Uri wsUri(String path, Map<String, String> query) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}$path',
      queryParameters: query,
    );
  }

  static const Duration timeout = Duration(seconds: 15);

  /// Seconds between polls of the order while a tracking screen is open.
  /// Only used as a fallback when the WebSocket is unavailable.
  static const Duration pollInterval = Duration(seconds: 5);
}
