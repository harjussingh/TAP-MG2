import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'review_screen.dart';

/// Four discrete stages rather than a map. A stage stays accurate between
/// polls in a way a moving position would not, which is why this model suits
/// polling the backend rather than holding a live connection open.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _timer;
  int _remaining = 293;

  @override
  void initState() {
    super.initState();
    // Stands in for polling the backend for the current stage.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
        if (_remaining == 288) _setStage(OrderStage.preparing);
        if (_remaining == 0) _setStage(OrderStage.ready);
      });
    });
  }

  void _setStage(OrderStage stage) {
    widget.order.stage = stage;
    AppScope.of(context).advanceOrder(stage);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final order = widget.order;
    final stage = order.stage;
    final isReady = stage == OrderStage.ready;
    final isDone = stage == OrderStage.completed;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.id}'),
            Text('${order.collectionBay} \u00b7 Machine ${order.machine}',
                style: AppTypography.secondary),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          if (isReady || isDone)
            _StatusBanner(
              label: 'STATUS',
              headline: isDone ? 'Completed' : 'Ready now!',
              pill: isDone
                  ? 'Collected. Enjoy!'
                  : 'Bowl complete \u2014 ready at ${order.collectionBay} \u{1F963}',
              pillDark: isDone,
            )
          else
            _EtaCard(countdown: _countdown),
          const SizedBox(height: AppSpacing.cardGap),
          _Stepper(stage: stage),
          const SizedBox(height: AppSpacing.cardGap),
          _BayCard(order: order),
          const SizedBox(height: AppSpacing.cardGap),
          // Demo controls so a stage can be shown on request during a
          // presentation. Remove once the backend drives the stage.
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final s in [
                OrderStage.preparing,
                OrderStage.ready,
                OrderStage.completed
              ])
                ActionChip(
                  label: Text('\u26A1 ${s.title.split(' ').first}'),
                  backgroundColor:
                      stage == s ? AppColors.primary : AppColors.card,
                  onPressed: () => setState(() {
                    _timer?.cancel();
                    if (s == OrderStage.preparing) _remaining = 293;
                    if (s != OrderStage.preparing) _remaining = 0;
                    _setStage(s);
                  }),
                ),
            ],
          ),
          if (isDone) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(order: order)),
              ),
              child: const Text('\u2B50 Leave a review'),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.countdown});

  final String countdown;

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
          Text('ETA',
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.sm),
          Text(countdown,
              style: AppTypography.screenTitle.copyWith(fontSize: 44)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.header,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text('Machine 2 is assembling your bowl...',
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
    required this.pillDark,
  });

  final String label;
  final String headline;
  final String pill;
  final bool pillDark;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        children: [
          Text(label,
              style: AppTypography.label.copyWith(
                  color: AppColors.success, letterSpacing: 1.4)),
          const SizedBox(height: AppSpacing.sm),
          Text(headline,
              style: AppTypography.screenTitle
                  .copyWith(fontSize: 40, color: AppColors.success)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: pillDark ? AppColors.base : AppColors.success,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text(pill,
                style: AppTypography.secondary.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.stage});

  final OrderStage stage;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final stages = OrderStage.values;
    final currentIndex = stages.indexOf(stage);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        children: [
          for (var i = 0; i < stages.length; i++)
            _StepRow(
              stage: stages[i],
              done: i < currentIndex,
              active: i == currentIndex,
              isLast: i == stages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.stage,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final OrderStage stage;
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
                        : const Text('\u2022',
                            style: TextStyle(fontSize: 14)),
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
                  Text(stage.title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            reached ? AppColors.base : AppColors.textSecondary,
                      )),
                  Text(stage.detail, style: AppTypography.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BayCard extends StatelessWidget {
  const _BayCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COLLECTION BAY',
                  style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 1.2)),
              Text(order.collectionBay, style: AppTypography.sectionHeading),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('MACHINE',
                  style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 1.2)),
              Text(order.machine, style: AppTypography.sectionHeading),
            ],
          ),
        ],
      ),
    );
  }
}
