import 'api_client.dart';
import 'api_models.dart';
import 'token_store.dart';

/// Every backend call the customer app makes.
///
/// One method per endpoint, named after what the screen is doing rather than
/// after the HTTP verb, so screens never build paths or parse JSON.
class RoboKitchenApi {
  RoboKitchenApi({required TokenStore store, ApiClient? client})
      : _store = store,
        _c = client ?? ApiClient(store: store);

  final TokenStore _store;
  final ApiClient _c;

  // ------------------------------------------------------------------ auth

  Future<AuthResult> login(String email, String password) async {
    final json = await _c.post('/auth/login',
        body: {'email': email, 'password': password}) as Map<String, dynamic>;
    final result = AuthResult.fromJson(json);
    await _store.saveTokens(result.accessToken, result.refreshToken);
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    bool marketingOptIn = false,
  }) async {
    final json = await _c.post('/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'marketing_opt_in': marketingOptIn,
    }) as Map<String, dynamic>;
    final result = AuthResult.fromJson(json);
    await _store.saveTokens(result.accessToken, result.refreshToken);
    return result;
  }

  Future<void> logout() async {
    final refresh = _store.refreshToken;
    if (refresh != null) {
      try {
        await _c.post('/auth/logout', body: {'refresh_token': refresh});
      } on ApiException {
        // Already invalid on the server; clearing locally is still correct.
      }
    }
    await _store.clearTokens();
  }

  Future<ApiUser> me() async =>
      ApiUser.fromJson(await _c.get('/auth/me') as Map<String, dynamic>);

  /// Always returns success, whether or not the account exists, so the screen
  /// must not reveal anything either.
  Future<void> forgotPassword(String email) =>
      _c.post('/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword(String token, String newPassword) => _c.post(
      '/auth/reset-password',
      body: {'token': token, 'new_password': newPassword});

  Future<void> changePassword(String current, String next) => _c.post(
      '/users/me/change-password',
      body: {'current_password': current, 'new_password': next});

  Future<ApiUser> updateProfile({
    String? fullName,
    String? phone,
    List<String>? dietaryPreferences,
    List<String>? allergens,
    bool? marketingOptIn,
  }) async =>
      ApiUser.fromJson(await _c.patch('/users/me', body: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (dietaryPreferences != null)
          'dietary_preferences': dietaryPreferences,
        if (allergens != null) 'allergens': allergens,
        if (marketingOptIn != null) 'marketing_opt_in': marketingOptIn,
      }) as Map<String, dynamic>);

  // ----------------------------------------------------------------- table

  /// The printed QR points at FRONTEND_URL/?table=CODE. Read the code from
  /// the deep link, then call this.
  Future<TableScan> scanTable(String code) async =>
      TableScan.fromJson(await _c.get('/tables/scan/$code') as Map<String, dynamic>);

  // ------------------------------------------------------------------ menu

  Future<List<Category>> categories() async =>
      ((await _c.get('/menu/categories')) as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<Paged<MenuItem>> menuItems({
    String? categoryId,
    String? search,
    List<String> dietary = const [],
    List<String> excludeAllergens = const [],
    String? itemType,
    bool? featured,
    int page = 1,
    int size = 50,
  }) async =>
      Paged.fromJson(
        await _c.get('/menu/items', query: {
          'category_id': categoryId,
          'search': search,
          if (dietary.isNotEmpty) 'dietary': dietary,
          if (excludeAllergens.isNotEmpty)
            'exclude_allergens': excludeAllergens,
          'item_type': itemType,
          'featured': featured,
          'page': page,
          'size': size,
        }) as Map<String, dynamic>,
        MenuItem.fromJson,
      );

  /// Use this before opening the builder: the list endpoint may not expand
  /// option groups, the detail endpoint always does.
  Future<MenuItem> menuItem(String idOrSlug) async =>
      MenuItem.fromJson(await _c.get('/menu/items/$idOrSlug') as Map<String, dynamic>);

  /// Live price as the customer picks. Debounce roughly 250ms.
  ///
  /// Throws 422 when a group's min or max rule is broken and 409 when an
  /// ingredient is sold out; both carry a message that can be shown directly.
  Future<PriceQuote> priceQuote({
    required String menuItemId,
    required List<Selection> selections,
    int quantity = 1,
  }) async =>
      PriceQuote.fromJson(await _c.post('/menu/price-quote', body: {
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'selections': selections.map((s) => s.toJson()).toList(),
      }) as Map<String, dynamic>);

  // ------------------------------------------------------------------ cart

  Future<Cart> cart({int redeemPoints = 0, int tipCents = 0}) async =>
      Cart.fromJson(await _c.get('/cart', query: {
        'redeem_points': redeemPoints,
        'tip_cents': tipCents,
      }) as Map<String, dynamic>);

  Future<Cart> addToCart({
    required String menuItemId,
    List<Selection> selections = const [],
    int quantity = 1,
    String? specialInstructions,
  }) async =>
      Cart.fromJson(await _c.post('/cart/items', body: {
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'selections': selections.map((s) => s.toJson()).toList(),
        if (specialInstructions != null && specialInstructions.isNotEmpty)
          'special_instructions': specialInstructions,
      }) as Map<String, dynamic>);

  Future<Cart> updateCartLine(String lineId, {int? quantity}) async =>
      Cart.fromJson(await _c.patch('/cart/items/$lineId',
          body: {if (quantity != null) 'quantity': quantity}) as Map<String, dynamic>);

  Future<Cart> removeCartLine(String lineId) async =>
      Cart.fromJson(await _c.delete('/cart/items/$lineId') as Map<String, dynamic>);

  Future<Cart> clearCart() async =>
      Cart.fromJson(await _c.delete('/cart') as Map<String, dynamic>);

  /// Attach the scanned table, or switch to takeaway.
  Future<Cart> setCartContext({String? tableCode, required OrderType type}) async =>
      Cart.fromJson(await _c.put('/cart/context', body: {
        'table_code': tableCode,
        'order_type': type.wire,
      }) as Map<String, dynamic>);

  /// Call immediately after login or register, or the guest's cart is orphaned.
  Future<Cart> mergeGuestCart() async =>
      Cart.fromJson(await _c.post('/cart/merge') as Map<String, dynamic>);

  // ---------------------------------------------------------------- orders

  Future<CheckoutResult> checkout({
    required PaymentMethod method,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? notes,
    int tipCents = 0,
    int redeemPoints = 0,
  }) async {
    final json = await _c.post('/orders/checkout', body: {
      'payment_method': method.wire,
      'tip_cents': tipCents,
      'redeem_points': redeemPoints,
      if (customerName != null) 'customer_name': customerName,
      if (customerEmail != null && customerEmail.isNotEmpty)
        'customer_email': customerEmail,
      if (customerPhone != null && customerPhone.isNotEmpty)
        'customer_phone': customerPhone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }) as Map<String, dynamic>;

    final result = CheckoutResult.fromJson(json);
    // Without this a guest can never see their order again.
    await _store.saveOrderToken(result.order.id, result.orderAccessToken);
    return result;
  }

  /// Development only, when the backend runs with PAYMENT_PROVIDER=mock.
  Future<Order> mockConfirmPayment(String orderId) async => Order.fromJson(
      await _c.post('/payments/$orderId/mock-confirm', orderId: orderId)
          as Map<String, dynamic>);

  Future<Order> order(String orderId) async => Order.fromJson(
      await _c.get('/orders/$orderId', orderId: orderId) as Map<String, dynamic>);

  Future<Paged<Order>> myOrders({int page = 1, int size = 20}) async =>
      Paged.fromJson(
        await _c.get('/orders/me', query: {'page': page, 'size': size})
            as Map<String, dynamic>,
        Order.fromJson,
      );

  Future<Order> cancelOrder(String orderId, {String? reason}) async =>
      Order.fromJson(await _c.post('/orders/$orderId/cancel',
          body: {'reason': reason}, orderId: orderId) as Map<String, dynamic>);

  /// Copies the order back into the cart. Returns how many lines were added
  /// and the names of anything no longer available.
  Future<({int added, List<String> skipped})> reorder(String orderId) async {
    final json = await _c.post('/orders/$orderId/reorder', orderId: orderId)
        as Map<String, dynamic>;
    return (
      added: json['added'] as int? ?? 0,
      skipped: ((json['skipped'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  // --------------------------------------------------------------- reviews

  Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) =>
      _c.post('/reviews', orderId: orderId, body: {
        'order_id': orderId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'tags': tags,
      });

  // --------------------------------------------------------- saved recipes

  Future<List<SavedRecipe>> savedRecipes() async =>
      ((await _c.get('/recipes')) as List<dynamic>)
          .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<SavedRecipe> saveRecipe({
    required String name,
    required String menuItemId,
    required List<Selection> selections,
  }) async =>
      SavedRecipe.fromJson(await _c.post('/recipes', body: {
        'name': name,
        'menu_item_id': menuItemId,
        'selections': selections.map((s) => s.toJson()).toList(),
      }) as Map<String, dynamic>);

  Future<void> deleteRecipe(String id) => _c.delete('/recipes/$id');

  Future<Cart> addRecipeToCart(String id, {int quantity = 1}) async =>
      Cart.fromJson(await _c.post('/recipes/$id/add-to-cart',
          query: {'quantity': quantity}) as Map<String, dynamic>);

  // --------------------------------------------------------------- loyalty

  Future<LoyaltySummary> loyalty() async => LoyaltySummary.fromJson(
      await _c.get('/loyalty/summary') as Map<String, dynamic>);

  void dispose() => _c.dispose();
}
