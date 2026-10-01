import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The 1 to 6 indicator across the top of the bowl builder.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, this.total = 6});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          _Dot(index: i, current: current),
          if (i < total)
            Expanded(
              child: Container(
                height: 2,
                color: i < current ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.current});

  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final done = index < current;
    final active = index == current;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.border,
      ),
      child: done
          ? Icon(Icons.check, size: 16, color: AppColors.onPrimary)
          : Text('$index',
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? AppColors.base : AppColors.textSecondary,
              )),
    );
  }
}
