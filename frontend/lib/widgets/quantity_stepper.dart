import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The minus / count / plus control.
///
/// Both reference apps put this next to the price rather than inside the
/// button, so the customer sets the quantity before committing rather than
/// tapping Add four times.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.compact = false,
    this.onColour,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// A tighter version for cart rows.
  final bool compact;

  /// Set when the stepper sits on a coloured card.
  final Color? onColour;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final ink = onColour ?? AppColors.base;
    final size = compact ? 30.0 : 36.0;

    return Container(
      padding: EdgeInsets.all(compact ? 3 : 4),
      decoration: BoxDecoration(
        color: onColour == null
            ? AppColors.surface
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(
          color: onColour == null
              ? AppColors.border
              : Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Button(
            icon: Icons.remove,
            size: size,
            ink: ink,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 28 : 36),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700, color: ink),
            ),
          ),
          _Button(
            icon: Icons.add,
            size: size,
            ink: ink,
            enabled: value < max,
            filled: true,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.size,
    required this.ink,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final Color ink;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? (enabled ? AppColors.primary : AppColors.disabled)
        : Colors.transparent;

    return Semantics(
      button: true,
      label: icon == Icons.add ? 'Increase quantity' : 'Decrease quantity',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: filled
                ? AppColors.onPrimary
                : ink.withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }
}
