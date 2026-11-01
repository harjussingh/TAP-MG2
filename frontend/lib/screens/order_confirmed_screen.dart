import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'order_tracking_screen.dart';

/// No QR code here. The order number identifies the order, and the items are
/// listed so the customer can check what was sent before it is cooked.
class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 40, color: AppColors.success),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Order placed!',
                textAlign: TextAlign.center, style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
                order.status == OrderStatus.pendingPayment
                    ? 'Waiting for your payment to go through.'
                    : 'Your bowl is in the queue.',
                textAlign: TextAlign.center,
                style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.header,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER',
                          style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2)),
                      Text(order.number,
                          style: AppTypography.sectionHeading
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('READY IN',
                          style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2)),
                      Text(_eta(order),
                          style: AppTypography.sectionHeading
                              .copyWith(color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            _Panel(
              label: 'ITEMS ORDERED',
              child: Column(
                children: [
                  for (final line in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    line.quantity > 1
                                        ? '${line.quantity} \u00d7 ${line.name}'
                                        : line.name,
                                    style: AppTypography.body
                                        .copyWith(fontWeight: FontWeight.w600)),
                                if (line.summary.isNotEmpty)
                                  Text(line.summary,
                                      style: AppTypography.secondary),
                              ],
                            ),
                          ),
                          Text(formatCents(line.lineTotalCents),
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _Panel(
              child: Column(
                children: [
                  _Row(
                      label: 'Subtotal',
                      value: formatCents(order.pricing.subtotalCents)),
                  if (order.pricing.discountCents > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _Row(
                        label: 'Points discount',
                        value: '-${formatCents(order.pricing.discountCents)}',
                        muted: true),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  _Row(
                      label: 'GST',
                      value: formatCents(order.pricing.taxCents),
                      muted: true),
                  if (order.pricing.serviceFeeCents > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _Row(
                        label: 'Service fee',
                        value: formatCents(order.pricing.serviceFeeCents),
                        muted: true),
                  ],
                  const Divider(height: AppSpacing.xl),
                  _Row(
                      label: 'Total',
                      value: formatCents(order.pricing.totalCents),
                      bold: true),
                ],
              ),
            ),
            _Panel(
              child: Row(
                children: [
                  Icon(Icons.restaurant, color: AppColors.base),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.placeLabel,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          order.orderType == OrderType.dineIn
                              ? 'Your bowl will be brought to your table'
                              : 'Collect from the counter when ready',
                          style: AppTypography.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                    builder: (_) => OrderTrackingScreen(order: order)),
              ),
              child: const Text('Track my order \u2192'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to menu'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "~6 min", or a dash until the kitchen has worked out a time.
String _eta(Order order) {
  final left = order.timeRemaining;
  if (left == null) return '\u2014';
  final minutes = (left.inSeconds / 60).ceil();
  return minutes <= 0 ? 'Now' : '~$minutes min';
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
