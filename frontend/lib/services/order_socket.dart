import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';
import 'api_models.dart';
import 'token_store.dart';

/// Live order updates.
///
/// The backend pushes `order.snapshot` on connect and `order.updated` after
/// that, so the tracking screen does not have to poll. A `ping` every 25
/// seconds keeps the connection open; the server answers `pong`.
///
/// If the socket cannot be opened the caller falls back to polling, which the
/// four-stage status model tolerates: a discrete stage stays correct between
/// polls in a way a moving position would not.
class OrderSocket {
  OrderSocket({required TokenStore store, required this.orderId})
      : _store = store;

  final TokenStore _store;
  final String orderId;

  WebSocketChannel? _channel;
  Timer? _ping;
  Timer? _retry;
  bool _stopped = false;
  Duration _backoff = const Duration(seconds: 1);

  final _controller = StreamController<Order>.broadcast();
  Stream<Order> get orders => _controller.stream;

  void connect() {
    _stopped = false;
    _open();
  }

  void _open() {
    // A guest authenticates with their order token, a member with the JWT.
    final token = _store.orderToken(orderId) ?? _store.accessToken;
    if (token == null) return;

    try {
      final uri = ApiConfig.wsUri('/ws/orders/$orderId', {'token': token});
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {
          // The listener's onDone handles reconnecting.
        }
      });

      channel.stream.listen(
        (message) {
          if (message == 'pong') return;
          try {
            final decoded = jsonDecode(message as String);
            if (decoded is! Map) return;
            final event = decoded['event'] as String?;
            if (event == 'order.snapshot' || event == 'order.updated') {
              _backoff = const Duration(seconds: 1);
              _controller.add(
                  Order.fromJson(decoded['data'] as Map<String, dynamic>));
            }
          } catch (_) {
            // Ignore anything unparseable rather than killing the stream.
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _ping?.cancel();
    if (_stopped) return;
    _retry?.cancel();
    _retry = Timer(_backoff, () {
      _backoff = Duration(
          seconds: (_backoff.inSeconds * 2).clamp(1, 30));
      _open();
    });
  }

  Future<void> dispose() async {
    _stopped = true;
    _ping?.cancel();
    _retry?.cancel();
    await _channel?.sink.close();
    await _controller.close();
  }
}
