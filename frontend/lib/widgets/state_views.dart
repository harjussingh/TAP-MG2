import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shown when a list has no content. Always offers a way forward rather than
/// only stating that nothing is there.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.border, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTypography.secondary, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Errors say what happened and what to do next, in plain language.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTypography.secondary, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A placeholder shaped like a dish card, so the layout does not shift when
/// the real content arrives.
class DishCardSkeleton extends StatefulWidget {
  const DishCardSkeleton({super.key});

  @override
  State<DishCardSkeleton> createState() => _DishCardSkeletonState();
}

class _DishCardSkeletonState extends State<DishCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: FadeTransition(
        opacity: reduceMotion
            ? const AlwaysStoppedAnimation(0.6)
            : Tween<double>(begin: 0.45, end: 0.85).animate(_controller),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(width: 64, height: 20),
                  SizedBox(height: AppSpacing.sm),
                  _Bar(width: 150, height: 18),
                  SizedBox(height: AppSpacing.sm),
                  _Bar(width: 210, height: 14),
                  SizedBox(height: AppSpacing.md),
                  _Bar(width: 90, height: 18),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            _Bar(width: AppSpacing.thumbnailSize, height: AppSpacing.thumbnailSize),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
      ),
    );
  }
}
