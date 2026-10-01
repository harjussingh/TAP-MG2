/// Everything that changes between environments.
class ApiConfig {
  const ApiConfig._();

  /// The backend is versioned, so the version is part of the base URL.
  ///
  /// On an Android emulator your laptop is not localhost: a server on port
  /// 8000 is reachable at 10.0.2.2. On a physical phone use the laptop's LAN
  /// address with both devices on the same Wi-Fi.
  ///
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://your-app.onrender.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

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
