enum OrderType {
  dineIn('Dine-in'),
  takeaway('Takeaway'),
  delivery('Delivery');

  const OrderType(this.label);
  final String label;
}

enum UserRole { guest, member }

enum OrderStage {
  received('Order received', 'Your order is in the queue'),
  preparing('Preparing', 'Machine 2 is building your bowl'),
  ready('Ready for collection', 'Collect from Bay 3'),
  completed('Completed', 'Enjoy your meal!');

  const OrderStage(this.title, this.detail);
  final String title;
  final String detail;
}

/// One line in the cart. Built from either a listed dish or a custom bowl.
class CartLine {
  const CartLine({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.price,
    required this.kilojoules,
    this.isCustom = false,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final double price;
  final int kilojoules;
  final bool isCustom;
}

class Order {
  Order({
    required this.id,
    required this.lines,
    required this.type,
    required this.tableNumber,
    required this.total,
    required this.placedAt,
    this.stage = OrderStage.received,
    this.rating,
  });

  final String id;
  final List<CartLine> lines;
  final OrderType type;
  final String tableNumber;
  final double total;
  final DateTime placedAt;

  OrderStage stage;
  int? rating;

  /// Australian prices are GST inclusive, so GST is one eleventh of the total.
  double get gst => total / 11;

  int get etaSeconds => 5 * 60;

  String get collectionBay => 'Bay 3';
  String get machine => 'No. 2';
}
