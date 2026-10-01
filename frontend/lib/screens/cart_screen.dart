import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/state_views.dart';
import 'checkout_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final subtitle = state.orderType == OrderType.dineIn &&
            state.tableNumber.isNotEmpty
        ? '${state.orderType.label} \u00b7 Table ${state.tableNumber}'
        : state.orderType.label;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your cart'),
            Text(subtitle,
                style: AppTypography.secondary
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: state.cart.isEmpty
          ? EmptyStateView(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add a bowl and it will show up here.',
              actionLabel: 'Browse the menu',
              onAction: () => Navigator.pop(context),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                for (var i = 0; i < state.cart.length; i++)
                  _Line(
                    line: state.cart[i],
                    onRemove: () => setState(() => state.removeFromCart(i)),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (state.orderType == OrderType.dineIn) _tableCard(state),
                // The promo code is member only, so a guest never sees it.
                if (state.isMember) _promoCard(),
                _totalsCard(state),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
      bottomNavigationBar: state.cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatPrice(state.cartTotal),
                            style: AppTypography.cardTitle),
                        Text(
                            '${state.cart.length} item'
                            '${state.cart.length == 1 ? '' : 's'}',
                            style: AppTypography.secondary),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 190,
                      child: ElevatedButton(
                        onPressed: () {
                          state.setTableNumber(_table.text);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const CheckoutScreen()),
                          );
                        },
                        child: const Text('Checkout \u2192'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tableCard(AppState state) => _Card(
        label: 'TABLE NUMBER',
        child: TextField(
          controller: _table,
          keyboardType: TextInputType.number,
          style: AppTypography.body,
          decoration: const InputDecoration(hintText: 'Enter table number'),
        ),
      );

  Widget _promoCard() => _Card(
        label: 'PROMO CODE',
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: AppTypography.body,
                decoration:
                    const InputDecoration(hintText: 'e.g. WELCOME10'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 96,
              height: AppSpacing.inputHeight,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      );

  Widget _totalsCard(AppState state) {
    final gst = state.cartTotal / 11;
    return _Card(
      child: Column(
        children: [
          _Row(label: 'Subtotal', value: formatPrice(state.cartTotal)),
          const Divider(height: AppSpacing.xl),
          _Row(label: 'Total', value: formatPrice(state.cartTotal), bold: true),
          const SizedBox(height: AppSpacing.xs),
          _Row(
              label: 'Includes GST',
              value: formatPrice(gst),
              muted: true),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.onRemove});

  final CartLine line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmojiTile(emoji: line.emoji, colour: AppColors.tileBlue, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.title, style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(line.subtitle,
                    style: AppTypography.secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatPrice(line.price),
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(formatKilojoules(line.kilojoules),
                        style: AppTypography.secondary),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: AppColors.error),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: AppTypography.label.copyWith(letterSpacing: 1.2)),
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
    SettingsScope.watch(context);
    final style = muted
        ? AppTypography.secondary
        : AppTypography.body.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontSize: bold ? 18 : 16);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}
