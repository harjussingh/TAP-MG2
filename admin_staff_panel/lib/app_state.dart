import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'format.dart';

enum LiveState { connecting, live, offline }

/// Signed-in user, API client and live connection, shared by every screen.
class AppState extends ChangeNotifier {
  AppState(this.api, {this.liveUpdates = true}) {
    api.onSessionExpired = () {
      _closeSocket();
      user = null;
      notifyListeners();
    };
  }

  final ApiClient api;

  /// Live WebSocket updates (tests switch this off; the 15 s refresh still runs).
  final bool liveUpdates;
  Map<String, dynamic>? user;

  bool get isManager => user?['role'] == 'admin';

  /// Fires on live socket events; live screens (board, robot, today, orders) reload on it.
  final _liveCounter = ValueNotifier<int>(0);
  Listenable get liveSignal => _liveCounter;
  void requestRefresh() => _liveCounter.value++;

  /// Order ids that arrived over the socket, with arrival time; the board highlights them briefly.
  final Map<String, DateTime> freshOrders = {};

  bool isFresh(Object? orderId, DateTime now) {
    final at = freshOrders[orderId];
    if (at == null) return false;
    if (now.difference(at) < const Duration(seconds: 10)) return true;
    freshOrders.remove(orderId);
    return false;
  }

  /// New-order announcements for the shell to toast.
  final _announcements = StreamController<String>.broadcast();
  Stream<String> get announcements => _announcements.stream;

  LiveState live = LiveState.offline;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _ping;
  Timer? _reconnect;
  Duration _backoff = const Duration(seconds: 1);

  /// Restores a saved session on page reload. Returns true when signed in.
  Future<bool> restore() async {
    await api.restore();
    if (!api.hasSession) return false;
    try {
      final me = await api.get('/users/me') as Map<String, dynamic>;
      if (me['role'] != 'admin' && me['role'] != 'staff') {
        await api.clear();
        return false;
      }
      user = me;
      await _loadCurrency();
      _openSocket();
      notifyListeners();
      return true;
    } catch (_) {
      await api.clear();
      return false;
    }
  }

  /// Signs in. [asManager] mirrors the station picked on the sign-in screen.
  Future<void> signIn(String email, String password, {required bool asManager}) async {
    final t = await api.login(email.trim(), password);
    final u = (t['user'] as Map).cast<String, dynamic>();
    final role = u['role'];
    if (role == 'customer') {
      throw ApiException('This account is a customer account. Use a staff or manager login.');
    }
    if (asManager && role != 'admin') {
      throw ApiException('This account is not a manager. Sign in as kitchen staff instead.');
    }
    await api.setTokens(t);
    user = u;
    await _loadCurrency();
    _openSocket();
    notifyListeners();
  }

  /// Currency for money formatting; public, so it works for staff and managers alike.
  Future<void> _loadCurrency() async {
    try {
      final cfg = await api.get('/payments/config');
      if (cfg is Map && cfg['currency'] is String) currencyCode = (cfg['currency'] as String).toUpperCase();
    } catch (_) {}
  }

  Future<void> signOut() async {
    _closeSocket();
    await api.logout();
    user = null;
    freshOrders.clear();
    notifyListeners();
  }

  // ---------------- live socket ----------------

  void _setLive(LiveState s) {
    if (live == s) return;
    live = s;
    notifyListeners();
  }

  void _openSocket() {
    _closeSocket();
    if (!api.hasSession || !liveUpdates) return;
    _setLive(LiveState.connecting);
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(api.staffSocketUri());
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    _ws = ch;
    ch.ready.then((_) {
      if (_ws != ch) return;
      _backoff = const Duration(seconds: 1);
      _setLive(LiveState.live);
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          ch.sink.add('ping');
        } catch (_) {}
      });
    }).catchError((_) {
      if (_ws == ch) _scheduleReconnect();
    });
    _wsSub = ch.stream.listen(
      _onMessage,
      onError: (_) {
        if (_ws == ch) _scheduleReconnect();
      },
      onDone: () {
        if (_ws == ch) _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _onMessage(dynamic raw) {
    if (raw is! String || raw == 'pong') return;
    Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final data = msg['data'];
    if (msg['event'] == 'order.created' && data is Map) {
      final id = data['id'];
      if (id is String) freshOrders[id] = DateTime.now();
      _announcements.add('New order #${data['order_number']}');
    }
    requestRefresh();
  }

  void _scheduleReconnect() {
    _closeSocket();
    if (user == null) return;
    _setLive(LiveState.offline);
    _reconnect = Timer(_backoff, () async {
      // The access token may have expired while offline; any authenticated call renews it.
      try {
        await api.get('/users/me');
      } catch (_) {}
      if (user != null) _openSocket();
    });
    final next = _backoff * 2;
    _backoff = next > const Duration(seconds: 20) ? const Duration(seconds: 20) : next;
  }

  void _closeSocket() {
    _ping?.cancel();
    _ping = null;
    _reconnect?.cancel();
    _reconnect = null;
    _wsSub?.cancel();
    _wsSub = null;
    final ws = _ws;
    _ws = null;
    if (ws != null) {
      try {
        ws.sink.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _closeSocket();
    _announcements.close();
    _liveCounter.dispose();
    super.dispose();
  }
}

/// Makes [AppState] available to every widget below it.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (use in callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
