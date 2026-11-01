import 'package:flutter/widgets.dart';

import 'models/bowl.dart';
import 'models/dish.dart';
import 'models/order.dart';
import 'models/user_profile.dart';
import 'services/api_client.dart';
import 'services/api_models.dart'
    show ApiUser, LoyaltySummary, MenuItem, SavedRecipe, Selection;
import 'services/robokitchen_api.dart';
import 'services/token_store.dart';

/// Single source of truth for the session.
///
/// Deliberately written with ChangeNotifier and InheritedNotifier so the app
/// runs with no state-management package. Swap in Riverpod or Bloc later if
/// the team prefers; only [AppScope.of] calls would change.
///
/// Everything that matters lives on the server: the cart, prices, orders and
/// the profile. This class holds the latest copy the server returned and is
/// the only place screens go through to change any of it.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store, this.liveUpdates = true});

  static Future<AppState> create() async {
    final store = await TokenStore.open();
    return AppState(api: RoboKitchenApi(store: store), store: store);
  }

  final RoboKitchenApi api;
  final TokenStore store;

  /// False in widget tests, where no WebSocket server is running. Order
  /// tracking then relies on polling alone.
  final bool liveUpdates;

  UserRole role = UserRole.guest;

  /// Null for a guest. Set when a member signs in.
  UserProfile? profile;

  /// The server's cart. Null until the table or takeaway is chosen.
  Cart? cart;

  final List<Order> history = [];
  bool historyLoaded = false;

  final List<SavedRecipe> savedRecipes = [];

  /// The member's saved recipes as bowls the builder can reopen. Rebuilt
  /// from [savedRecipes] against today's menu whenever either changes.
  final List<Bowl> savedBowls = [];

  /// The latest menu, kept so the builder and saved recipes can find the
  /// build-your-own item without another round trip.
  List<Dish> menu = const [];

  /// The build-your-own item, which carries the builder's option groups.
  MenuItem? get customBowlItem {
    for (final d in menu) {
      if (d.isCustom && d.item != null) return d.item;
    }
    return null;
  }

  LoyaltySummary? loyalty;

  Order? activeOrder;

  /// Set when the app was opened from a table's QR code (`?table=CODE`).
  String? pendingTableCode;

  /// Remembered so switching from takeaway back to dine-in keeps the table.
  int? _lastTableNumber;

  bool get isMember => role == UserRole.member;

  OrderType get orderType => cart?.orderType ?? OrderType.dineIn;

  /// Two digits, as printed on the table. Empty when there is no table.
  String get tableNumber {
    final table = cart?.table;
    return table == null ? '' : tableLabel(table.number);
  }

  List<CartLine> get cartLines => cart?.items ?? const [];

  int get cartCount => cart?.itemCount ?? 0;

  void _setCart(Cart value) {
    cart = value;
    if (value.table != null) _lastTableNumber = value.table!.number;
  }

  void setRole(UserRole value) {
    role = value;
    notifyListeners();
  }

  // ------------------------------------------------------------- session

  /// Signs a returning member back in with the saved tokens.
  Future<void> restoreSession() async {
    if (!store.keepSignedIn) await store.clearTokens();
    if (store.accessToken == null) return;
    try {
      _becomeMember(await api.me());
      notifyListeners();
      await _loadSavedQuietly();
    } on ApiException catch (e) {
      if (e.isUnauthenticated) await store.clearTokens();
    }
  }

  Future<void> login(String email, String password,
      {bool keepSignedIn = true}) async {
    final result = await api.login(email, password);
    await store.setKeepSignedIn(keepSignedIn);
    await _afterAuth(result.user);
  }

  /// Returns the server's message when the account still has to be verified
  /// by email; in that case the person is not signed in yet.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    bool keepSignedIn = true,
  }) async {
    final result =
        await api.register(email: email, password: password, fullName: name);
    if (!result.isSignedIn) {
      return result.message ??
          'Check your email to verify your account, then log in.';
    }
    await store.setKeepSignedIn(keepSignedIn);
    await _afterAuth(result.user);
    return null;
  }

  Future<void> _afterAuth(ApiUser user) async {
    _becomeMember(user);
    // Without the merge the guest's cart would be orphaned.
    try {
      _setCart(await api.mergeGuestCart());
    } on ApiException {
      // The member's own cart is still fine; it loads on the next refresh.
    }
    historyLoaded = false;
    notifyListeners();
    await _loadSavedQuietly();
  }

  /// Saved recipes drive the hearts on dish pages, so they load with the
  /// session. A failure here is not worth interrupting sign-in for.
  Future<void> _loadSavedQuietly() async {
    try {
      await loadSaved();
    } on ApiException {
      // The Saved tab retries when it opens.
    }
  }

  void _becomeMember(ApiUser user) {
    role = UserRole.member;
    profile =
        UserProfile.fromApi(user, orderUpdates: profile?.orderUpdates ?? true);
  }

  /// Clears the whole session. The caller sends the user back to the entry
  /// screen; leaving them inside the app as a guest would be wrong.
  Future<void> signOut() async {
    await api.logout();
    await store.forgetGuestOrders();
    role = UserRole.guest;
    profile = null;
    cart = null;
    _lastTableNumber = null;
    history.clear();
    historyLoaded = false;
    savedRecipes.clear();
    savedBowls.clear();
    loyalty = null;
    activeOrder = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- table

  Future<void> chooseTable(int number) async {
    _setCart(
        await api.setCartContext(tableNumber: number, type: OrderType.dineIn));
    notifyListeners();
  }

  Future<void> chooseTableByCode(String code) async {
    _setCart(await api.setCartContext(tableCode: code, type: OrderType.dineIn));
    pendingTableCode = null;
    notifyListeners();
  }

  Future<void> chooseTakeaway() async {
    _setCart(await api.setCartContext(type: OrderType.takeaway));
    notifyListeners();
  }

  /// Returns false when dine-in was picked but no table is known yet, so the
  /// caller can ask for one.
  Future<bool> setOrderType(OrderType value) async {
    if (value == OrderType.takeaway) {
      await chooseTakeaway();
      return true;
    }
    final number = cart?.table?.number ?? _lastTableNumber;
    if (number == null) return false;
    await chooseTable(number);
    return true;
  }

  // ---------------------------------------------------------------- menu

  Future<List<Dish>> loadMenu() async {
    final page = await api.menuItems(includeUnavailable: true, size: 100);
    menu = page.items.map(Dish.fromMenuItem).toList();
    _rebuildSavedBowls();
    notifyListeners();
    return menu;
  }

  /// The custom bowl item with its option groups, from the menu if it has
  /// been loaded, otherwise straight from the server.
  Future<MenuItem?> loadCustomBowlItem() async {
    if (customBowlItem != null) return customBowlItem;
    await loadMenu();
    return customBowlItem;
  }

  // ---------------------------------------------------------------- cart

  Future<void> refreshCart() async {
    _setCart(await api.cart());
    notifyListeners();
  }

  Future<void> addToCart(String menuItemId,
      {List<Selection> selections = const [],
      int quantity = 1,
      String? specialInstructions}) async {
    _setCart(await api.addToCart(
        menuItemId: menuItemId,
        selections: selections,
        quantity: quantity,
        specialInstructions: specialInstructions));
    notifyListeners();
  }

  /// Sends a finished bowl from the builder to the cart.
  Future<void> addBowlToCart(Bowl bowl) => addToCart(bowl.item!.id,
      selections: bowl.toSelections(),
      specialInstructions: bowl.specialInstructions);

  Future<void> setLineQuantity(String lineId, int quantity) async {
    _setCart(await api.updateCartLine(lineId, quantity: quantity));
    notifyListeners();
  }

  Future<void> removeLine(String lineId) async {
    _setCart(await api.removeCartLine(lineId));
    notifyListeners();
  }

  // -------------------------------------------------------------- orders

  /// Places the order. With the mock payment provider a card payment is
  /// confirmed straight away; a real provider leaves it waiting for payment.
  Future<Order> checkout({
    required PaymentMethod method,
    String? name,
    String? email,
    String? phone,
    int redeemPoints = 0,
  }) async {
    final result = await api.checkout(
      method: method,
      customerName: name,
      customerEmail: email,
      customerPhone: phone,
      redeemPoints: redeemPoints,
    );
    var order = result.order;
    if (method == PaymentMethod.card &&
        result.requiresAction &&
        result.isMock) {
      order = await api.mockConfirmPayment(order.id);
    }
    activeOrder = order;
    _upsert(order);
    try {
      _setCart(await api.cart());
    } on ApiException {
      // The order is placed either way; the cart refreshes next time.
    }
    if (redeemPoints > 0) loyalty = null;
    notifyListeners();
    return order;
  }

  Future<void> loadHistory() async {
    final List<Order> orders;
    if (isMember) {
      orders = (await api.myOrders(size: 50)).items;
    } else {
      orders = [];
      for (final id in store.guestOrderIds) {
        try {
          orders.add(await api.order(id));
        } on ApiException {
          // Gone or no longer viewable; skip it.
        }
      }
    }
    history
      ..clear()
      ..addAll(orders);
    historyLoaded = true;
    notifyListeners();
  }

  Future<Order> refreshOrder(String orderId) async {
    final order = await api.order(orderId);
    applyOrder(order);
    return order;
  }

  /// Takes a newer copy of an order, from a poll or the WebSocket.
  void applyOrder(Order order) {
    if (activeOrder?.id == order.id) activeOrder = order;
    _upsert(order);
    notifyListeners();
  }

  void _upsert(Order order) {
    final i = history.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      history[i] = order;
    } else {
      history.insert(0, order);
    }
  }

  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    final order = await api.cancelOrder(orderId, reason: reason);
    applyOrder(order);
    return order;
  }

  /// Copies a past order into the cart. Returns what could not be added.
  Future<({int added, List<String> skipped})> reorder(String orderId) async {
    final result = await api.reorder(orderId);
    await refreshCart();
    return result;
  }

  Future<void> submitReview(Order order,
      {required int rating,
      String? comment,
      List<String> tags = const []}) async {
    await api.submitReview(
        orderId: order.id, rating: rating, comment: comment, tags: tags);
    try {
      await refreshOrder(order.id);
    } on ApiException {
      // The review is saved; the badge updates on the next refresh.
    }
  }

  // ------------------------------------------------------- saved recipes

  Future<void> loadSaved() async {
    final list = await api.savedRecipes();
    savedRecipes
      ..clear()
      ..addAll(list);
    if (customBowlItem == null && list.isNotEmpty) {
      try {
        await loadMenu();
      } on ApiException {
        // The recipes still list; reopening them waits for the menu.
      }
    }
    _rebuildSavedBowls();
    notifyListeners();
  }

  void _rebuildSavedBowls() {
    savedBowls
      ..clear()
      ..addAll([
        for (final r in savedRecipes)
          Bowl.fromRecipe(r, _itemFor(r.menuItemId) ?? _placeholderItem(r)),
      ]);
  }

  MenuItem? _itemFor(String id) {
    for (final d in menu) {
      if (d.id == id) return d.item;
    }
    return null;
  }

  /// Until the menu loads, a recipe still needs an item to hang off.
  MenuItem _placeholderItem(SavedRecipe r) => MenuItem(
      id: r.menuItemId,
      name: r.menuItemName,
      slug: '',
      categoryId: '',
      basePriceCents: r.currentPriceCents ?? 0,
      itemType: 'custom_bowl');

  /// Saves a copy to the account, so later edits in the builder do not
  /// quietly rewrite the recipe already in the list.
  Future<void> saveBowl(Bowl bowl, {String? name}) async {
    final recipe = await api.saveRecipe(
      name: (name ?? bowl.displayName).trim(),
      menuItemId: bowl.item!.id,
      selections: bowl.toSelections(),
      specialInstructions: bowl.specialInstructions,
    );
    savedRecipes.insert(0, recipe);
    _rebuildSavedBowls();
    notifyListeners();
  }

  Future<void> removeSavedBowl(int index) async {
    if (index < 0 || index >= savedRecipes.length) return;
    await api.deleteRecipe(savedRecipes[index].id);
    savedRecipes.removeAt(index);
    _rebuildSavedBowls();
    notifyListeners();
  }

  /// Renames a saved recipe. An empty name falls back to the ingredients in
  /// the list, so the server is given that rather than a blank.
  Future<void> renameSavedBowl(int index, String name) async {
    if (index < 0 || index >= savedRecipes.length) return;
    final trimmed = name.trim();
    final updated = await api.renameRecipe(savedRecipes[index].id,
        trimmed.isEmpty ? savedBowls[index].suggestedName : trimmed);
    savedRecipes[index] = updated;
    _rebuildSavedBowls();
    notifyListeners();
  }

  /// A menu dish saved with the heart on its page (not a custom bowl).
  bool isDishSaved(String menuItemId) => _savedDishIndex(menuItemId) >= 0;

  int _savedDishIndex(String menuItemId) => savedRecipes.indexWhere(
      (r) => r.menuItemId == menuItemId && menuItemId != customBowlItem?.id);

  Future<void> toggleDishSaved(Dish dish) async {
    final i = _savedDishIndex(dish.id);
    if (i >= 0) {
      await removeSavedBowl(i);
      return;
    }
    final recipe = await api
        .saveRecipe(name: dish.name, menuItemId: dish.id, selections: const []);
    savedRecipes.insert(0, recipe);
    _rebuildSavedBowls();
    notifyListeners();
  }

  Future<void> addRecipeToCart(String id) async {
    _setCart(await api.addRecipeToCart(id));
    notifyListeners();
  }

  // ------------------------------------------------------------- profile

  Future<void> updateProfile({
    String? name,
    String? phone,
    Set<String>? dietary,
    Set<String>? allergens,
    bool? marketing,
  }) async {
    final user = await api.updateProfile(
      fullName: name,
      phone: phone,
      dietaryPreferences: dietary?.toList(),
      allergens: allergens?.toList(),
      marketingOptIn: marketing,
    );
    _becomeMember(user);
    notifyListeners();
  }

  void setOrderUpdates(bool value) {
    profile?.orderUpdates = value;
    notifyListeners();
  }

  Future<void> loadLoyalty() async {
    loyalty = await api.loyalty();
    profile?.loyaltyPoints = loyalty!.points;
    profile?.loyaltyTier = loyalty!.tier;
    notifyListeners();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}

/// What to show the person when a call fails.
String errorMessage(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope(
      {super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// For callbacks: reads the state without rebuilding when it changes.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
