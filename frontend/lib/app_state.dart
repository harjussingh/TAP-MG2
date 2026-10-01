import 'package:flutter/widgets.dart';

import 'models/bowl.dart';
import 'models/order.dart';
import 'models/user_profile.dart';

/// Single source of truth for the session.
///
/// Deliberately written with ChangeNotifier and InheritedNotifier so the app
/// runs with no state-management package. Swap in Riverpod or Bloc later if
/// the team prefers; only [AppScope.of] calls would change.
class AppState extends ChangeNotifier {
  UserRole role = UserRole.guest;

  /// Null for a guest. Set when a member signs in.
  UserProfile? profile;

  /// Returned by the backend at sign-in and sent on every later request.
  /// The role is read from this token on the server, never from the app.
  String? authToken;
  OrderType orderType = OrderType.dineIn;
  String tableNumber = '';

  final List<CartLine> cart = [];
  final List<Order> history = [];
  final List<Bowl> savedBowls = [];

  Order? activeOrder;

  bool get isMember => role == UserRole.member;

  double get cartTotal =>
      cart.fold<double>(0, (sum, line) => sum + line.price);

  int get cartKilojoules =>
      cart.fold<int>(0, (sum, line) => sum + line.kilojoules);

  void setRole(UserRole value) {
    role = value;
    notifyListeners();
  }

  /// Signing in sets the role and the profile together, so the app and the
  /// access rules can never disagree.
  void signIn(UserProfile user, {String? token}) {
    role = UserRole.member;
    profile = user;
    authToken = token;
    notifyListeners();
  }

  /// Clears the whole session. The caller sends the user back to the entry
  /// screen; leaving them inside the app as a guest would be wrong.
  void signOut() {
    role = UserRole.guest;
    profile = null;
    authToken = null;
    tableNumber = '';
    orderType = OrderType.dineIn;
    cart.clear();
    history.clear();
    savedBowls.clear();
    activeOrder = null;
    notifyListeners();
  }

  void updateProfile(UserProfile updated) {
    profile = updated;
    notifyListeners();
  }

  void setOrderType(OrderType value) {
    orderType = value;
    notifyListeners();
  }

  void setTableNumber(String value) {
    tableNumber = value;
    notifyListeners();
  }

  void addToCart(CartLine line) {
    cart.add(line);
    notifyListeners();
  }

  void removeFromCart(int index) {
    cart.removeAt(index);
    notifyListeners();
  }

  void saveBowl(Bowl bowl) {
    savedBowls.add(bowl.copy());
    notifyListeners();
  }

  Order placeOrder() {
    final order = Order(
      id: 'ROBO-${5000 + history.length * 7 + cart.length}',
      lines: List<CartLine>.from(cart),
      type: orderType,
      tableNumber: tableNumber,
      total: cartTotal,
      placedAt: DateTime.now(),
    );
    activeOrder = order;
    history.insert(0, order);
    cart.clear();
    notifyListeners();
    return order;
  }

  void advanceOrder(OrderStage stage) {
    activeOrder?.stage = stage;
    notifyListeners();
  }

  void rateOrder(Order order, int rating) {
    order.rating = rating;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
