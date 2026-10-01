import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import 'order_confirmed_screen.dart';

/// Payment is simulated for this phase and is labelled as such on screen so
/// no reviewer mistakes it for a live facility.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  /// The API accepts card, cash and pay_at_counter and nothing else.
  /// Apple Pay, Google Pay, PayPal and Afterpay are not implemented
  /// server-side, so they are not offered here.
  static const _methods = [
    ('card', 'Card', Icons.credit_card),
    ('cash', 'Cash', Icons.payments_outlined),
    ('pay_at_counter', 'Pay at counter', Icons.point_of_sale),
  ];

  int _selected = 0;
  bool _processing = false;

  Future<void> _placeOrder() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final order = AppScope.of(context).placeOrder();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => OrderConfirmedScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final total = state.cartTotal;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.tileCream,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Demo payment \u2014 simulation only. No real charges are made.',
                    style: AppTypography.secondary
                        .copyWith(color: AppColors.base),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Panel(
            label: 'ORDER SUMMARY',
            child: Column(
              children: [
                for (final line in state.cart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(line.title, style: AppTypography.body)),
                        Text(formatPrice(line.price),
                            style: AppTypography.body),
                      ],
                    ),
                  ),
                const Divider(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(formatPrice(total),
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Includes GST ${formatPrice(total / 11)}',
                      style: AppTypography.secondary),
                ),
              ],
            ),
          ),
          _Panel(
            label: 'PAYMENT METHOD',
            child: Column(
              children: [
                for (var i = 0; i < _methods.length; i++)
                  _MethodRow(
                    label: _methods[i].$2,
                    icon: _methods[i].$3,
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                  ),
              ],
            ),
          ),
          if (state.orderType == OrderType.dineIn &&
              state.tableNumber.isNotEmpty)
            _Panel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Table', style: AppTypography.body),
                  Text('Table ${state.tableNumber}',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
      bottomNavigationBar: SafeArea(
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
                  Text(formatPrice(total), style: AppTypography.cardTitle),
                  Text('via ${_methods[_selected].$2}',
                      style: AppTypography.secondary),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  // Disabled while the simulated payment runs.
                  onPressed: _processing ? null : _placeOrder,
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Place order \u{1F916}'),
                ),
              ),
            ],
          ),
        ),
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
                style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
      child: Container(
        height: AppSpacing.minTouchTarget + 8,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.tileCream : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.base),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.body)),
            if (selected)
              Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
