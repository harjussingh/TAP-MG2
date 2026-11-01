import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/state_views.dart';
import 'checkout_screen.dart';

/// The order before it is sent.
///
/// The cart lives on the server. Each row is one server line with its own
/// quantity, which is how people think about an order: "two tuna bowls", not
/// "a tuna bowl and another tuna bowl". Every change returns the whole cart
/// with freshly calculated prices, and that is what is shown.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _table = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await state.refreshCart();
      _table.text = state.tableNumber;
      if (state.isMember) {
        try {
          await state.loadLoyalty();
        } catch (_) {
          // The points card simply stays hidden.
        }
      }
    } catch (e) {
      _loadError = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _table.dispose();
    super.dispose();
  }

  /// Runs one cart change, keeping the screen responsive and showing the
  /// server's message if it is refused.
  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkout(AppState state) async {
    // A changed table number is checked by the server before moving on.
    if (state.orderType == OrderType.dineIn) {
      final typed = int.tryParse(_table.text.trim());
      if (typed == null || typed < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your table number first')),
        );
        return;
      }
      if (state.cart?.table?.number != typed) {
        var ok = false;
        await _change(() async {
          await state.chooseTable(typed);
          ok = true;
        });
        if (!ok || !mounted) return;
        _table.text = state.tableNumber;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final cart = state.cart;
    final lines = state.cartLines;

    final subtitle =
        state.orderType == OrderType.dineIn && state.tableNumber.isNotEmpty
            ? '${state.orderType.label} · Table ${state.tableNumber}'
            : state.orderType.label;

    Widget body;
    if (_loading && cart == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null && cart == null) {
      body = ErrorStateView(
        title: "We couldn't load your order",
        message: _loadError!,
        onRetry: _load,
      );
    } else if (lines.isEmpty) {
      body = EmptyStateView(
        icon: Icons.shopping_bag_outlined,
        title: 'Nothing here yet',
        message: 'Add a bowl and it will show up here.',
        actionLabel: 'Browse the menu',
        onAction: () => Navigator.pop(context),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          for (final line in lines)
            _LineCard(
              line: line,
              enabled: !_busy,
              onQuantity: (v) =>
                  _change(() => state.setLineQuantity(line.lineId, v)),
              onRemove: () => _change(() => state.removeLine(line.lineId)),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (state.orderType == OrderType.dineIn) _tableCard(),
          // Loyalty points are a member benefit, so a guest never sees the
          // card. The server enforces this too.
          if (state.isMember && state.loyalty != null) _loyaltyCard(state),
          _totalsCard(cart!.totals),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your order'),
            Text(subtitle,
                style: AppTypography.secondary.copyWith(
                    color: AppColors.onHeader.withValues(alpha: 0.7))),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar:
          lines.isEmpty || cart == null ? null : _checkoutBar(state, cart),
    );
  }

  Widget _tableCard() => _Panel(
        label: 'TABLE NUMBER',
        child: TextField(
          controller: _table,
          keyboardType: TextInputType.number,
          style: AppTypography.body,
          decoration: const InputDecoration(hintText: 'Enter table number'),
        ),
      );

  /// The API has no coupons: members earn and redeem loyalty points instead.
  Widget _loyaltyCard(AppState state) {
    final loyalty = state.loyalty!;
    final canRedeem = loyalty.points >= loyalty.minPointsToRedeem;
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.stars_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loyalty.points} loyalty points',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                    canRedeem
                        ? 'Use them at checkout, worth up to '
                            '${formatCents(loyalty.redeemableValueCents)}'
                        : 'Redeem at checkout from '
                            '${loyalty.minPointsToRedeem} points',
                    style: AppTypography.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(Totals totals) {
    final taxPercent = (totals.taxRate * 100)
        .toStringAsFixed(totals.taxRate * 100 % 1 == 0 ? 0 : 1);
    return _Panel(
      child: Column(
        children: [
          _Row(label: 'Subtotal', value: formatCents(totals.subtotalCents)),
          if (totals.discountCents > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _Row(
                label: 'Points discount',
                value: '-${formatCents(totals.discountCents)}',
                muted: true),
          ],
          const SizedBox(height: AppSpacing.sm),
          _Row(
              label: 'GST ($taxPercent%)',
              value: formatCents(totals.taxCents),
              muted: true),
          if (totals.serviceFeeCents > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _Row(
                label: 'Service fee',
                value: formatCents(totals.serviceFeeCents),
                muted: true),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _Row(
              label: 'Total',
              value: formatCents(totals.totalCents),
              bold: true),
        ],
      ),
    );
  }

  Widget _checkoutBar(AppState state, Cart cart) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatCents(cart.totals.totalCents),
                      style: AppTypography.cardTitle
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      cart.hasErrors
                          ? 'Fix the items marked above'
                          : '${state.cartCount} item'
                              '${state.cartCount == 1 ? '' : 's'}',
                      style: AppTypography.secondary.copyWith(
                          color: cart.hasErrors ? AppColors.error : null)),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: ElevatedButton(
                  // Blocked while a line needs attention.
                  onPressed:
                      _busy || cart.hasErrors ? null : () => _checkout(state),
                  child: const Text('Checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.enabled,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartLine line;
  final bool enabled;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isCustom = line.itemType == 'custom_bowl';
    final details = [
      if (line.summary.isNotEmpty) line.summary,
      if (line.specialInstructions != null) line.specialInstructions!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
            color: line.error == null ? AppColors.border : AppColors.error),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmojiTile(
                  emoji: foodEmoji(line.name),
                  colour: AppColors.tileBlue,
                  size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(line.name,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tileBlue,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text('Custom',
                                style:
                                    AppTypography.label.copyWith(fontSize: 11)),
                          ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(details,
                          style: AppTypography.secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (line.error != null) ...[
                      const SizedBox(height: 2),
                      Text(line.error!,
                          style: AppTypography.secondary
                              .copyWith(color: AppColors.error)),
                    ],
                    if (line.calories > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                          formatKilojoules(caloriesToKilojoules(
                              line.calories * line.quantity)),
                          style: AppTypography.label
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              QuantityStepper(
                value: line.quantity,
                compact: true,
                max: 20,
                onChanged: enabled ? onQuantity : (_) {},
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Remove ${line.name}',
              ),
              const Spacer(),
              Text(formatCents(line.lineTotalCents),
                  style: AppTypography.cardTitle
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: AppTypography.label.copyWith(
                    letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = muted
        ? AppTypography.secondary
        : AppTypography.body.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontSize: bold ? 19 : 16);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
