// Orders, carts and their parts come straight from the API. Re-exported here
// so screens keep importing one models file.
export '../services/api_models.dart'
    show
        Cart,
        CartLine,
        CheckoutResult,
        Order,
        OrderStatus,
        OrderType,
        PaymentMethod,
        PricedSelection,
        StatusEvent,
        TableRef,
        Totals,
        caloriesToKilojoules,
        formatCents;

import '../services/api_models.dart';

/// Who is using the app. Separate from the account role on the server: a
/// guest has no account at all.
enum UserRole { guest, member }

/// The four steps on the tracking screen.
const List<OrderStatus> kTrackerSteps = [
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.completed,
];

extension OrderStatusDisplay on OrderStatus {
  String get title => switch (this) {
        OrderStatus.pendingPayment => 'Waiting for payment',
        OrderStatus.confirmed => 'Order received',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready for collection',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get detail => switch (this) {
        OrderStatus.pendingPayment => 'Finish paying to send it to the kitchen',
        OrderStatus.confirmed => 'Your order is in the queue',
        OrderStatus.preparing => 'The machine is building your bowl',
        OrderStatus.ready => 'Collect it from the counter',
        OrderStatus.completed => 'Enjoy your meal!',
        OrderStatus.cancelled => 'This order was cancelled',
      };
}

extension OrderDisplay on Order {
  String get number => '#$orderNumber';

  /// "Dine-in · Table 07" or "Takeaway".
  String get placeLabel => orderType == OrderType.dineIn && table != null
      ? '${orderType.label} · Table ${tableLabel(table!.number)}'
      : orderType.label;
}

/// Table numbers are shown with two digits, the way they are printed.
String tableLabel(int number) => number.toString().padLeft(2, '0');
