import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'order_confirmed_screen.dart';

/// Places the order on the server. Card payments are simulated while the
/// backend runs with PAYMENT_PROVIDER=mock, and the screen says so, so no
/// reviewer mistakes it for a live facility.
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
    (PaymentMethod.card, Icons.credit_card),
    (PaymentMethod.cash, Icons.payments_outlined),
    (PaymentMethod.payAtCounter, Icons.point_of_sale),
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  int _selected = 0;
  bool _processing = false;
  bool _usePoints = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.read(context);
      if (!state.isMember) return;
      try {
        await state.loadLoyalty();
      } catch (_) {
        // Points are optional; checkout works without them.
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final state = AppScope.read(context);
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final loyalty = state.loyalty;
      final order = await state.checkout(
        method: _methods[_selected].$1,
        name: state.isMember ? null : _name.text.trim(),
        email: state.isMember ? null : _email.text.trim(),
        redeemPoints: _usePoints && loyalty != null ? loyalty.points : 0,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
            builder: (_) => OrderConfirmedScreen(order: order)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final totals = state.cart?.totals;
    final total = totals?.totalCents ?? 0;
    final loyalty = state.loyalty;
    final canRedeem = state.isMember &&
        loyalty != null &&
        loyalty.points >= loyalty.minPointsToRedeem;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            if (_methods[_selected].$1 == PaymentMethod.card)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
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
                        'Demo payment — simulation only. No real charges are made.',
                        style: AppTypography.secondary
                            .copyWith(color: AppColors.base),
                      ),
                    ),
                  ],
                ),
              ),
            _Panel(
              label: 'ORDER SUMMARY',
              child: Column(
                children: [
                  for (final line in state.cartLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(
                                  line.quantity > 1
                                      ? '${line.quantity} × ${line.name}'
                                      : line.name,
                                  style: AppTypography.body)),
                          Text(formatCents(line.lineTotalCents),
                              style: AppTypography.body),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.xl),
                  if (totals != null) ...[
                    _Line(label: 'Subtotal', cents: totals.subtotalCents),
                    if (totals.discountCents > 0)
                      _Line(
                          label: 'Points discount',
                          cents: -totals.discountCents),
                    _Line(label: 'GST', cents: totals.taxCents),
                    if (totals.serviceFeeCents > 0)
                      _Line(
                          label: 'Service fee', cents: totals.serviceFeeCents),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: AppTypography.cardTitle
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(formatCents(total),
                          style: AppTypography.cardTitle
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (_usePoints)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Points come off the total when the order is placed',
                          style: AppTypography.secondary),
                    ),
                ],
              ),
            ),
            // A guest has no account, so the kitchen needs a name to call out.
            if (!state.isMember)
              _Panel(
                label: 'YOUR DETAILS',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      style: AppTypography.body,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Name for the order'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter a name for the order'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _email,
                      style: AppTypography.body,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          hintText: 'Email for the receipt (optional)'),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value)
                            ? null
                            : 'That does not look like an email address';
                      },
                    ),
                  ],
                ),
              ),
            if (canRedeem)
              _Panel(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _usePoints,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _usePoints = v),
                  title: Text('Use my ${loyalty.points} points',
                      style: AppTypography.body),
                  subtitle: Text(
                      'Worth up to ${formatCents(loyalty.redeemableValueCents)}',
                      style: AppTypography.secondary),
                ),
              ),
            _Panel(
              label: 'PAYMENT METHOD',
              child: Column(
                children: [
                  for (var i = 0; i < _methods.length; i++)
                    _MethodRow(
                      label: _methods[i].$1.label,
                      icon: _methods[i].$2,
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
            if (_error != null)
              Text(_error!,
                  style:
                      AppTypography.secondary.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCents(total), style: AppTypography.cardTitle),
                    Text('via ${_methods[_selected].$1.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  // Disabled while the order is being placed.
                  onPressed: _processing || state.cartLines.isEmpty
                      ? null
                      : _placeOrder,
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

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.secondary),
          Text(cents < 0 ? '-${formatCents(-cents)}' : formatCents(cents),
              style: AppTypography.secondary),
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
            if (selected) Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
