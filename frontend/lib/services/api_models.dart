/// Dart mirrors of the backend's response schemas.
///
/// Two rules carried over from the API and worth keeping in mind everywhere:
/// money is **integer cents**, and prices are **never calculated here** — the
/// server returns them, the app displays them.
library;

String formatCents(int cents, {String currency = 'AUD'}) {
  final symbol = currency.toUpperCase() == 'AUD' ? '\$' : '\$';
  return '$symbol${(cents / 100).toStringAsFixed(2)}';
}

enum UserRole { customer, staff, admin }

enum OrderType {
  dineIn('dine_in', 'Dine-in'),
  takeaway('takeaway', 'Takeaway');

  const OrderType(this.wire, this.label);
  final String wire;
  final String label;

  static OrderType fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => OrderType.dineIn);
}

/// Six statuses, not four. `pending_payment` and `cancelled` both need
/// handling in the interface.
enum OrderStatus {
  pendingPayment('pending_payment', 'Waiting for payment'),
  confirmed('confirmed', 'Order received'),
  preparing('preparing', 'Preparing'),
  ready('ready', 'Ready for collection'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.wire, this.label);
  final String wire;
  final String label;

  static OrderStatus fromWire(String? v) => values
      .firstWhere((e) => e.wire == v, orElse: () => OrderStatus.confirmed);

  /// Position on the four-step tracker. pending_payment sits before it and
  /// cancelled sits outside it.
  int get trackerIndex => switch (this) {
        OrderStatus.pendingPayment => 0,
        OrderStatus.confirmed => 0,
        OrderStatus.preparing => 1,
        OrderStatus.ready => 2,
        OrderStatus.completed => 3,
        OrderStatus.cancelled => -1,
      };
}

enum PaymentMethod {
  card('card', 'Card'),
  cash('cash', 'Cash'),
  payAtCounter('pay_at_counter', 'Pay at counter');

  const PaymentMethod(this.wire, this.label);
  final String wire;
  final String label;
}

enum PaymentStatus { unpaid, pending, paid, failed, refunded }

class ApiUser {
  ApiUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.emailVerified = false,
    this.dietaryPreferences = const [],
    this.allergens = const [],
    this.marketingOptIn = false,
    this.loyaltyPoints = 0,
    this.lifetimePoints = 0,
    this.loyaltyTier = 'bronze',
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final bool emailVerified;
  final List<String> dietaryPreferences;
  final List<String> allergens;
  final bool marketingOptIn;
  final int loyaltyPoints;
  final int lifetimePoints;
  final String loyaltyTier;

  bool get isStaff => role == UserRole.staff || role == UserRole.admin;

  String get initial => fullName.isEmpty ? '?' : fullName[0].toUpperCase();

  factory ApiUser.fromJson(Map<String, dynamic> j) => ApiUser(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['full_name'] as String? ?? '',
        role: UserRole.values.firstWhere((r) => r.name == j['role'],
            orElse: () => UserRole.customer),
        phone: j['phone'] as String?,
        emailVerified: j['email_verified'] as bool? ?? false,
        dietaryPreferences: _strings(j['dietary_preferences']),
        allergens: _strings(j['allergens']),
        marketingOptIn: j['marketing_opt_in'] as bool? ?? false,
        loyaltyPoints: j['loyalty_points'] as int? ?? 0,
        lifetimePoints: j['lifetime_points'] as int? ?? 0,
        loyaltyTier: j['loyalty_tier'] as String? ?? 'bronze',
      );
}

class AuthResult {
  AuthResult({this.accessToken, this.refreshToken, required this.user});

  final String? accessToken;
  final String? refreshToken;
  final ApiUser user;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['access_token'] as String?,
        refreshToken: j['refresh_token'] as String?,
        user: ApiUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class TableRef {
  TableRef({required this.id, required this.number, this.name});

  final String id;
  final int number;
  final String? name;

  String get display => name ?? 'Table $number';

  factory TableRef.fromJson(Map<String, dynamic> j) => TableRef(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String?,
      );
}

class TableScan {
  TableScan({
    required this.table,
    required this.restaurantName,
    required this.isAcceptingOrders,
    required this.currency,
  });

  final TableRef table;
  final String restaurantName;

  /// False when an admin has paused ordering. Checkout must be blocked.
  final bool isAcceptingOrders;
  final String currency;

  factory TableScan.fromJson(Map<String, dynamic> j) => TableScan(
        table: TableRef.fromJson(j['table'] as Map<String, dynamic>),
        restaurantName: j['restaurant_name'] as String? ?? '',
        isAcceptingOrders: j['is_accepting_orders'] as bool? ?? true,
        currency: j['currency'] as String? ?? 'aud',
      );
}

class Category {
  Category({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
      );
}

/// One choice inside an option group, already resolved by the server with its
/// name, price, calories and availability.
class MenuOption {
  MenuOption({
    required this.ingredientId,
    required this.name,
    required this.priceCents,
    this.calories = 0,
    this.allergens = const [],
    this.dietaryTags = const [],
    this.imageUrl,
    this.isDefault = false,
    this.isAvailable = true,
  });

  final String ingredientId;
  final String name;
  final int priceCents;
  final int calories;
  final List<String> allergens;
  final List<String> dietaryTags;
  final String? imageUrl;
  final bool isDefault;

  /// False when the ingredient is sold out. Show it rather than hiding it, so
  /// the customer understands why the choice is unavailable.
  final bool isAvailable;

  factory MenuOption.fromJson(Map<String, dynamic> j) => MenuOption(
        ingredientId: j['ingredient_id'] as String,
        name: j['name'] as String,
        priceCents: j['price_cents'] as int? ?? 0,
        calories: j['calories'] as int? ?? 0,
        allergens: _strings(j['allergens']),
        dietaryTags: _strings(j['dietary_tags']),
        imageUrl: j['image_url'] as String?,
        isDefault: j['is_default'] as bool? ?? false,
        isAvailable: j['is_available'] as bool? ?? true,
      );
}

/// A step in the bowl builder. The steps are not hard-coded in the app: they
/// come from the item's option groups, so an admin adding a group adds a step.
class OptionGroup {
  OptionGroup({
    required this.key,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.options,
  });

  final String key;
  final String name;
  final int minSelect;
  final int maxSelect;
  final List<MenuOption> options;

  bool get isRequired => minSelect > 0;

  factory OptionGroup.fromJson(Map<String, dynamic> j) => OptionGroup(
        key: j['key'] as String,
        name: j['name'] as String,
        minSelect: j['min_select'] as int? ?? 0,
        maxSelect: j['max_select'] as int? ?? 1,
        options: ((j['options'] as List<dynamic>?) ?? const [])
            .map((e) => MenuOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MenuItem {
  MenuItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryId,
    required this.basePriceCents,
    required this.itemType,
    this.description = '',
    this.imageUrl,
    this.tags = const [],
    this.dietaryTags = const [],
    this.allergens = const [],
    this.calories = 0,
    this.isAvailable = true,
    this.isFeatured = false,
    this.ratingAvg,
    this.ratingCount = 0,
    this.optionGroups = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String categoryId;
  final int basePriceCents;

  /// `standard` or `custom_bowl`. A custom bowl opens the builder.
  final String itemType;

  final String description;
  final String? imageUrl;
  final List<String> tags;
  final List<String> dietaryTags;
  final List<String> allergens;
  final int calories;
  final bool isAvailable;
  final bool isFeatured;
  final double? ratingAvg;
  final int ratingCount;
  final List<OptionGroup> optionGroups;

  bool get isCustomBowl => itemType == 'custom_bowl';

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String? ?? '',
        categoryId: j['category_id'] as String? ?? '',
        basePriceCents: j['base_price_cents'] as int? ?? 0,
        itemType: j['item_type'] as String? ?? 'standard',
        description: j['description'] as String? ?? '',
        imageUrl: j['image_url'] as String?,
        tags: _strings(j['tags']),
        dietaryTags: _strings(j['dietary_tags']),
        allergens: _strings(j['allergens']),
        calories: j['calories'] as int? ?? 0,
        isAvailable: j['is_available'] as bool? ?? true,
        isFeatured: j['is_featured'] as bool? ?? false,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
        ratingCount: j['rating_count'] as int? ?? 0,
        optionGroups: ((j['option_groups'] as List<dynamic>?) ?? const [])
            .map((e) => OptionGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// What the app sends for one chosen ingredient.
class Selection {
  const Selection({
    required this.groupKey,
    required this.ingredientId,
    this.quantity = 1,
  });

  final String groupKey;
  final String ingredientId;

  /// Counts towards the group's max_select, so "double protein" is quantity 2.
  final int quantity;

  Map<String, dynamic> toJson() => {
        'group_key': groupKey,
        'ingredient_id': ingredientId,
        'quantity': quantity,
      };
}

class PricedSelection {
  PricedSelection({
    required this.groupKey,
    required this.groupName,
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.priceCents,
  });

  final String groupKey;
  final String groupName;
  final String ingredientId;
  final String name;
  final int quantity;
  final int priceCents;

  factory PricedSelection.fromJson(Map<String, dynamic> j) => PricedSelection(
        groupKey: j['group_key'] as String,
        groupName: j['group_name'] as String? ?? '',
        ingredientId: j['ingredient_id'] as String,
        name: j['name'] as String,
        quantity: j['quantity'] as int? ?? 1,
        priceCents: j['price_cents'] as int? ?? 0,
      );
}

/// The server's answer to "what would this bowl cost".
class PriceQuote {
  PriceQuote({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.calories = 0,
    this.allergens = const [],
    this.selections = const [],
  });

  final String menuItemId;
  final String name;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final int calories;
  final List<String> allergens;
  final List<PricedSelection> selections;

  factory PriceQuote.fromJson(Map<String, dynamic> j) => PriceQuote(
        menuItemId: j['menu_item_id'] as String,
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as int? ?? 1,
        unitPriceCents: j['unit_price_cents'] as int? ?? 0,
        lineTotalCents: j['line_total_cents'] as int? ?? 0,
        calories: j['calories'] as int? ?? 0,
        allergens: _strings(j['allergens']),
        selections: ((j['selections'] as List<dynamic>?) ?? const [])
            .map((e) => PricedSelection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CartLine {
  CartLine({
    required this.lineId,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.imageUrl,
    this.itemType = 'standard',
    this.selections = const [],
    this.calories = 0,
    this.allergens = const [],
    this.specialInstructions,
    this.error,
  });

  final String lineId;
  final String menuItemId;
  final String name;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final String? imageUrl;
  final String itemType;
  final List<PricedSelection> selections;
  final int calories;
  final List<String> allergens;
  final String? specialInstructions;

  /// Set when the line became unavailable after it was added. Show it and
  /// block checkout until the customer removes or edits the line.
  final String? error;

  String get summary =>
      selections.map((s) => s.name).join(' \u00b7 ');

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        lineId: j['line_id'] as String,
        menuItemId: j['menu_item_id'] as String,
        name: j['name'] as String,
        quantity: j['quantity'] as int? ?? 1,
        unitPriceCents: j['unit_price_cents'] as int? ?? 0,
        lineTotalCents: j['line_total_cents'] as int? ?? 0,
        imageUrl: j['image_url'] as String?,
        itemType: j['item_type'] as String? ?? 'standard',
        selections: ((j['selections'] as List<dynamic>?) ?? const [])
            .map((e) => PricedSelection.fromJson(e as Map<String, dynamic>))
            .toList(),
        calories: j['calories'] as int? ?? 0,
        allergens: _strings(j['allergens']),
        specialInstructions: j['special_instructions'] as String?,
        error: j['error'] as String?,
      );
}

class Totals {
  Totals({
    required this.subtotalCents,
    required this.taxCents,
    required this.serviceFeeCents,
    required this.totalCents,
    required this.taxRate,
    this.discountCents = 0,
    this.pointsRedeemed = 0,
    this.tipCents = 0,
  });

  final int subtotalCents;
  final int taxCents;
  final int serviceFeeCents;
  final int totalCents;
  final double taxRate;
  final int discountCents;
  final int pointsRedeemed;
  final int tipCents;

  factory Totals.fromJson(Map<String, dynamic> j) => Totals(
        subtotalCents: j['subtotal_cents'] as int? ?? 0,
        taxCents: j['tax_cents'] as int? ?? 0,
        serviceFeeCents: j['service_fee_cents'] as int? ?? 0,
        totalCents: j['total_cents'] as int? ?? 0,
        taxRate: (j['tax_rate'] as num?)?.toDouble() ?? 0,
        discountCents: j['discount_cents'] as int? ?? 0,
        pointsRedeemed: j['points_redeemed'] as int? ?? 0,
        tipCents: j['tip_cents'] as int? ?? 0,
      );
}

/// The cart lives on the server, not in the app. Every cart call returns the
/// whole cart with freshly calculated prices.
class Cart {
  Cart({
    required this.id,
    required this.items,
    required this.itemCount,
    required this.orderType,
    required this.totals,
    required this.currency,
    required this.hasErrors,
    this.table,
  });

  final String id;
  final List<CartLine> items;
  final int itemCount;
  final OrderType orderType;
  final Totals totals;
  final String currency;
  final bool hasErrors;
  final TableRef? table;

  bool get isEmpty => items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
        id: j['id'] as String,
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        itemCount: j['item_count'] as int? ?? 0,
        orderType: OrderType.fromWire(j['order_type'] as String?),
        totals: Totals.fromJson((j['totals'] as Map<String, dynamic>?) ?? {}),
        currency: j['currency'] as String? ?? 'aud',
        hasErrors: j['has_errors'] as bool? ?? false,
        table: j['table'] == null
            ? null
            : TableRef.fromJson(j['table'] as Map<String, dynamic>),
      );
}

class StatusEvent {
  StatusEvent({required this.status, required this.at, this.note});

  final OrderStatus status;
  final DateTime at;
  final String? note;

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: OrderStatus.fromWire(j['status'] as String?),
        at: DateTime.parse(j['at'] as String),
        note: j['note'] as String?,
      );
}

class PaymentInfo {
  PaymentInfo({required this.method, required this.status, this.paidAt});

  final String method;
  final PaymentStatus status;
  final DateTime? paidAt;

  bool get isPaid => status == PaymentStatus.paid;

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        method: j['method'] as String? ?? 'card',
        status: PaymentStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => PaymentStatus.unpaid),
        paidAt: j['paid_at'] == null
            ? null
            : DateTime.parse(j['paid_at'] as String),
      );
}

class Order {
  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.orderType,
    required this.items,
    required this.pricing,
    required this.currency,
    required this.payment,
    required this.createdAt,
    this.table,
    this.notes,
    this.statusHistory = const [],
    this.estimatedReadyAt,
    this.pointsEarned = 0,
    this.hasReview = false,
    this.cancelReason,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final OrderType orderType;
  final List<CartLine> items;
  final Totals pricing;
  final String currency;
  final PaymentInfo payment;
  final DateTime createdAt;
  final TableRef? table;
  final String? notes;
  final List<StatusEvent> statusHistory;
  final DateTime? estimatedReadyAt;
  final int pointsEarned;
  final bool hasReview;
  final String? cancelReason;

  /// Customers can only cancel before the robot starts.
  bool get canCancel =>
      status == OrderStatus.pendingPayment || status == OrderStatus.confirmed;

  bool get canReview =>
      !hasReview &&
      (status == OrderStatus.ready || status == OrderStatus.completed);

  Duration? get timeRemaining {
    final eta = estimatedReadyAt;
    if (eta == null) return null;
    final left = eta.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        orderNumber: j['order_number'] as int,
        status: OrderStatus.fromWire(j['status'] as String?),
        orderType: OrderType.fromWire(j['order_type'] as String?),
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        pricing: Totals.fromJson((j['pricing'] as Map<String, dynamic>?) ?? {}),
        currency: j['currency'] as String? ?? 'aud',
        payment:
            PaymentInfo.fromJson((j['payment'] as Map<String, dynamic>?) ?? {}),
        createdAt: DateTime.parse(j['created_at'] as String),
        table: j['table'] == null
            ? null
            : TableRef.fromJson(j['table'] as Map<String, dynamic>),
        notes: j['notes'] as String?,
        statusHistory: ((j['status_history'] as List<dynamic>?) ?? const [])
            .map((e) => StatusEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        estimatedReadyAt: j['estimated_ready_at'] == null
            ? null
            : DateTime.parse(j['estimated_ready_at'] as String),
        pointsEarned: j['points_earned'] as int? ?? 0,
        hasReview: j['has_review'] as bool? ?? false,
        cancelReason: j['cancel_reason'] as String?,
      );
}

/// What checkout gives back. The order token must be kept: it is the only way
/// a guest can see their order again.
class CheckoutResult {
  CheckoutResult({
    required this.order,
    required this.orderAccessToken,
    required this.provider,
    required this.requiresAction,
    this.clientSecret,
    this.publishableKey,
  });

  final Order order;
  final String orderAccessToken;
  final String provider;
  final bool requiresAction;
  final String? clientSecret;
  final String? publishableKey;

  bool get isMock => provider == 'mock';

  factory CheckoutResult.fromJson(Map<String, dynamic> j) {
    final payment = (j['payment'] as Map<String, dynamic>?) ?? {};
    return CheckoutResult(
      order: Order.fromJson(j['order'] as Map<String, dynamic>),
      orderAccessToken: j['order_access_token'] as String,
      provider: payment['provider'] as String? ?? 'mock',
      requiresAction: payment['requires_action'] as bool? ?? false,
      clientSecret: payment['client_secret'] as String?,
      publishableKey: payment['publishable_key'] as String?,
    );
  }
}

class SavedRecipe {
  SavedRecipe({
    required this.id,
    required this.name,
    required this.menuItemId,
    required this.menuItemName,
    required this.isAvailable,
    this.selections = const [],
    this.currentPriceCents,
    this.calories,
    this.unavailableReason,
    this.timesOrdered = 0,
  });

  final String id;
  final String name;
  final String menuItemId;
  final String menuItemName;
  final bool isAvailable;
  final List<PricedSelection> selections;
  final int? currentPriceCents;
  final int? calories;
  final String? unavailableReason;
  final int timesOrdered;

  factory SavedRecipe.fromJson(Map<String, dynamic> j) => SavedRecipe(
        id: j['id'] as String,
        name: j['name'] as String,
        menuItemId: j['menu_item_id'] as String,
        menuItemName: j['menu_item_name'] as String? ?? '',
        isAvailable: j['is_available'] as bool? ?? true,
        selections: ((j['selections'] as List<dynamic>?) ?? const [])
            .map((e) => PricedSelection.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentPriceCents: j['current_price_cents'] as int?,
        calories: j['calories'] as int?,
        unavailableReason: j['unavailable_reason'] as String?,
        timesOrdered: j['times_ordered'] as int? ?? 0,
      );
}

class LoyaltySummary {
  LoyaltySummary({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
    required this.redeemableValueCents,
    required this.minPointsToRedeem,
    this.nextTier,
    this.pointsToNextTier = 0,
  });

  final int points;
  final int lifetimePoints;
  final String tier;
  final int redeemableValueCents;
  final int minPointsToRedeem;
  final String? nextTier;
  final int pointsToNextTier;

  factory LoyaltySummary.fromJson(Map<String, dynamic> j) => LoyaltySummary(
        points: j['points'] as int? ?? 0,
        lifetimePoints: j['lifetime_points'] as int? ?? 0,
        tier: j['tier'] as String? ?? 'bronze',
        redeemableValueCents: j['redeemable_value_cents'] as int? ?? 0,
        minPointsToRedeem: j['min_points_to_redeem'] as int? ?? 100,
        nextTier: j['next_tier'] as String?,
        pointsToNextTier: j['points_to_next_tier'] as int? ?? 0,
      );
}

/// A page of results. The API paginates menu items, orders and reviews.
class Paged<T> {
  Paged({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  bool get hasMore => page < pages;

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Paged(
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => parse(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int? ?? 0,
        page: j['page'] as int? ?? 1,
        size: j['size'] as int? ?? 20,
        pages: j['pages'] as int? ?? 1,
      );
}

List<String> _strings(dynamic v) =>
    ((v as List<dynamic>?) ?? const []).map((e) => e.toString()).toList();
