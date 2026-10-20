import 'package:flutter/material.dart';

import '../app_state.dart';
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
/// Identical bowls are grouped into one row with a quantity, which is how
/// people think about an order: "two tuna bowls", not "a tuna bowl and another
/// tuna bowl".
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _table = TextEditingController();
  bool _seeded = false;

  /// Reading AppScope needs an inherited widget lookup, which must not happen
  /// part-way through build. didChangeDependencies is the right place.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _table.text = AppScope.of(context).tableNumber;
  }

  @override
  void dispose() {
    _table.dispose();
    super.dispose();
  }

  /// Groups the flat cart into rows of identical lines.
  List<_Group> _groups(AppState state) {
    final groups = <String, _Group>{};
    for (final line in state.cart) {
      final key = '${line.title}|${line.subtitle}';
      groups.putIfAbsent(key, () => _Group(line: line, count: 0)).count++;
    }
    return groups.values.toList();
  }

  void _setQuantity(AppState state, _Group group, int next) {
    setState(() {
      if (next > group.count) {
        state.addToCart(group.line);
        return;
      }
      for (var i = state.cart.length - 1; i >= 0; i--) {
        final line = state.cart[i];
        if (line.title == group.line.title &&
            line.subtitle == group.line.subtitle) {
          state.removeFromCart(i);
          return;
        }
      }
    });
  }

  void _removeAll(AppState state, _Group group) {
    setState(() {
      for (var i = state.cart.length - 1; i >= 0; i--) {
        final line = state.cart[i];
        if (line.title == group.line.title &&
            line.subtitle == group.line.subtitle) {
          state.removeFromCart(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final groups = _groups(state);

    final subtitle =
        state.orderType == OrderType.dineIn && state.tableNumber.isNotEmpty
            ? '${state.orderType.label} · Table ${state.tableNumber}'
            : state.orderType.label;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your order'),
            Text(subtitle,
                style: AppTypography.secondary
                    .copyWith(color: AppColors.onHeader.withValues(alpha: 0.7))),
          ],
        ),
      ),
      body: state.cart.isEmpty
          ? EmptyStateView(
              icon: Icons.shopping_bag_outlined,
              title: 'Nothing here yet',
              message: 'Add a bowl and it will show up here.',
              actionLabel: 'Browse the menu',
              onAction: () => Navigator.pop(context),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                for (final group in groups)
                  _LineCard(
                    group: group,
                    onQuantity: (v) => _setQuantity(state, group, v),
                    onRemove: () => _removeAll(state, group),
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (state.orderType == OrderType.dineIn) _tableCard(),
                // Loyalty points are a member benefit, so a guest never sees
                // the field. The server enforces this too.
                if (state.isMember) _loyaltyCard(),
                _totalsCard(state),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
      bottomNavigationBar:
          state.cart.isEmpty ? null : _checkoutBar(context, state),
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
  /// See INTEGRATION_CHECK.md 3.7.
  Widget _loyaltyCard() => _Panel(
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
                  Text('Loyalty points',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('Redeem at checkout, from 100 points',
                      style: AppTypography.secondary),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      );

  Widget _totalsCard(AppState state) {
    final gst = state.cartTotal / 11;
    return _Panel(
      child: Column(
        children: [
          _Row(label: 'Subtotal', value: formatPrice(state.cartTotal)),
          const SizedBox(height: AppSpacing.sm),
          _Row(label: 'Includes GST', value: formatPrice(gst), muted: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _Row(
              label: 'Total',
              value: formatPrice(state.cartTotal),
              bold: true),
        ],
      ),
    );
  }

  Widget _checkoutBar(BuildContext context, AppState state) {
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
                  Text(formatPrice(state.cartTotal),
                      style: AppTypography.cardTitle
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      '${state.cart.length} item'
                      '${state.cart.length == 1 ? '' : 's'}',
                      style: AppTypography.secondary),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    state.setTableNumber(_table.text);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const CheckoutScreen()),
                    );
                  },
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

class _Group {
  _Group({required this.line, required this.count});

  final CartLine line;
  int count;

  double get total => line.price * count;
  int get kilojoules => line.kilojoules * count;
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.group,
    required this.onQuantity,
    required this.onRemove,
  });

  final _Group group;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final line = group.line;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmojiTile(
                  emoji: line.emoji, colour: AppColors.tileBlue, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(line.title,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (line.isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tileBlue,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusPill),
                            ),
                            child: Text('Custom',
                                style:
                                    AppTypography.label.copyWith(fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(line.subtitle,
                        style: AppTypography.secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(formatKilojoules(group.kilojoules),
                        style: AppTypography.label
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              QuantityStepper(
                value: group.count,
                compact: true,
                onChanged: onQuantity,
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Remove ${line.title}',
              ),
              const Spacer(),
              Text(formatPrice(group.total),
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
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}
