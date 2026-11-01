import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../services/api_config.dart';
import '../services/order_socket.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'review_screen.dart';

/// Four discrete stages rather than a map. The server pushes each change over
/// a WebSocket; a slow poll runs underneath in case the socket drops, and a
/// discrete stage stays accurate between polls in a way a moving position
/// would not.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Order _order = widget.order;
  Timer? _poll;
  Timer? _tick;
  OrderSocket? _socket;
  StreamSubscription<Order>? _live;
  bool _cancelling = false;

  bool get _finished =>
      _order.status == OrderStatus.completed ||
      _order.status == OrderStatus.cancelled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final state = AppScope.read(context);
    if (state.liveUpdates) {
      final socket = OrderSocket(store: state.store, orderId: _order.id);
      _live = socket.orders.listen(_apply);
      socket.connect();
      _socket = socket;
    }
    _poll = Timer.periodic(ApiConfig.pollInterval, (_) => _refresh());
    // Redraws the countdown once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _order.estimatedReadyAt != null) setState(() {});
    });
    _refresh();
  }

  void _apply(Order order) {
    if (!mounted) return;
    setState(() => _order = order);
    AppScope.read(context).applyOrder(order);
    if (_finished) _poll?.cancel();
  }

  Future<void> _refresh() async {
    if (!mounted || _finished && _order.hasReview) return;
    try {
      _apply(await AppScope.read(context).api.order(_order.id));
    } catch (_) {
      // Keep showing the last known stage; the next poll tries again.
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cancel this order?'),
        content: Text(
          'You can cancel until the machine starts on it.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      _apply(await AppScope.read(context)
          .cancelOrder(_order.id, reason: 'Cancelled by customer'));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
    if (mounted) setState(() => _cancelling = false);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _live?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  String get _countdown {
    final left = _order.timeRemaining;
    if (left == null) return '—';
    final m = left.inMinutes;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final order = _order;
    final status = order.status;

    final Widget banner;
    switch (status) {
      case OrderStatus.cancelled:
        banner = _StatusBanner(
          label: 'STATUS',
          headline: 'Cancelled',
          pill: order.cancelReason ?? 'This order will not be made',
          colour: AppColors.error,
        );
      case OrderStatus.ready:
        banner = const _StatusBanner(
          label: 'STATUS',
          headline: 'Ready now!',
          pill: 'Bowl complete — collect it from the counter \u{1F963}',
          colour: AppColors.success,
        );
      case OrderStatus.completed:
        banner = const _StatusBanner(
          label: 'STATUS',
          headline: 'Completed',
          pill: 'Collected. Enjoy!',
          colour: AppColors.success,
          pillDark: true,
        );
      case OrderStatus.pendingPayment:
        banner = const _InfoCard(
          label: 'PAYMENT',
          headline: 'Waiting for payment',
          detail: 'The kitchen starts as soon as the payment goes through.',
        );
      case OrderStatus.confirmed || OrderStatus.preparing:
        banner = _InfoCard(
          label: 'ETA',
          headline: _countdown,
          detail: status == OrderStatus.preparing
              ? 'The machine is assembling your bowl...'
              : 'Your order is in the queue...',
        );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${order.number}'),
            Text(order.placeLabel, style: AppTypography.secondary),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            banner,
            const SizedBox(height: AppSpacing.cardGap),
            if (status != OrderStatus.cancelled) ...[
              _Stepper(status: status),
              const SizedBox(height: AppSpacing.cardGap),
            ],
            _DetailsCard(order: order),
            if (order.canCancel) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: _cancelling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: const Text('Cancel order'),
              ),
            ],
            if (order.canReview) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => ReviewScreen(order: order)),
                ),
                child: const Text('⭐ Leave a review'),
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.label, required this.headline, required this.detail});

  final String label;
  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label,
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.sm),
          Text(headline,
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle.copyWith(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.header,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text(detail,
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.headline,
    required this.pill,
    required this.colour,
    this.pillDark = false,
  });

  final String label;
  final String headline;
  final String pill;
  final Color colour;
  final bool pillDark;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: colour),
      ),
      child: Column(
        children: [
          Text(label,
              style: AppTypography.label
                  .copyWith(color: colour, letterSpacing: 1.4)),
          const SizedBox(height: AppSpacing.sm),
          Text(headline,
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle
                  .copyWith(fontSize: 40, color: colour)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: pillDark ? AppColors.base : colour,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text(pill,
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    // Waiting for payment sits before the first step, so nothing is ticked.
    final current =
        status == OrderStatus.pendingPayment ? -1 : status.trackerIndex;
    final finished = status == OrderStatus.completed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        children: [
          for (var i = 0; i < kTrackerSteps.length; i++)
            _StepRow(
              status: kTrackerSteps[i],
              done: i < current || (finished && i == current),
              active: i == current && !finished,
              isLast: i == kTrackerSteps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.status,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final OrderStatus status;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final reached = done || active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.success
                      : active
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.border,
                ),
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : active
                        ? RobomosLogo(
                            size: 16, badge: false, colour: AppColors.base)
                        : const Text('•', style: TextStyle(fontSize: 14)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            reached ? AppColors.base : AppColors.textSecondary,
                      )),
                  Text(status.detail, style: AppTypography.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final paid = order.payment.isPaid;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderType == OrderType.dineIn ? 'TABLE' : 'PICK UP',
                    style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary, letterSpacing: 1.2)),
                Text(
                    order.table == null
                        ? 'Counter'
                        : tableLabel(order.table!.number),
                    style: AppTypography.sectionHeading),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL',
                  style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 1.2)),
              Text(formatCents(order.pricing.totalCents),
                  style: AppTypography.sectionHeading),
              Text(paid ? 'Paid' : 'To pay',
                  style: AppTypography.secondary
                      .copyWith(color: paid ? AppColors.success : null)),
            ],
          ),
        ],
      ),
    );
  }
}
