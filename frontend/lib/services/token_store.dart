import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the things the API needs across app restarts.
///
/// The guest session id in particular has to survive a restart, because the
/// cart on the server is keyed to it. Losing it loses the cart.
class TokenStore {
  TokenStore._(this._prefs);

  static const _kAccess = 'rk_access';
  static const _kRefresh = 'rk_refresh';
  static const _kSession = 'rk_session';
  static const _kOrderToken = 'rk_order_';

  final SharedPreferences _prefs;

  static Future<TokenStore> open() async =>
      TokenStore._(await SharedPreferences.getInstance());

  String? get accessToken => _prefs.getString(_kAccess);
  String? get refreshToken => _prefs.getString(_kRefresh);

  Future<void> saveTokens(String? access, String? refresh) async {
    if (access == null || refresh == null) return;
    await _prefs.setString(_kAccess, access);
    await _prefs.setString(_kRefresh, refresh);
  }

  Future<void> clearTokens() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
  }

  /// Generated once and kept. Identifies the guest cart on the server.
  String get sessionId {
    var id = _prefs.getString(_kSession);
    if (id == null) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final rng = Random.secure();
      id = List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
      _prefs.setString(_kSession, id);
    }
    return id;
  }

  /// Guests need this to view, track, cancel and review an order they placed
  /// without an account.
  String? orderToken(String orderId) =>
      _prefs.getString('$_kOrderToken$orderId');

  Future<void> saveOrderToken(String orderId, String token) async {
    await _prefs.setString('$_kOrderToken$orderId', token);
    final ids = guestOrderIds;
    if (!ids.contains(orderId)) {
      await _prefs.setStringList(
          _kGuestOrders, [orderId, ...ids].take(20).toList());
    }
  }

  static const _kGuestOrders = 'rk_guest_orders';
  static const _kKeepSignedIn = 'rk_keep_signed_in';

  /// Orders placed on this device, newest first. A guest has no account to
  /// list them from, so this is how their History tab is filled.
  List<String> get guestOrderIds =>
      _prefs.getStringList(_kGuestOrders) ?? const [];

  Future<void> forgetGuestOrders() => _prefs.remove(_kGuestOrders);

  /// "Keep me signed in". When false the tokens are dropped on the next start.
  bool get keepSignedIn => _prefs.getBool(_kKeepSignedIn) ?? true;

  Future<void> setKeepSignedIn(bool value) =>
      _prefs.setBool(_kKeepSignedIn, value);
}
