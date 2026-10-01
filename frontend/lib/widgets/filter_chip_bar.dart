import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Chips are 40 high inside a 48 tap target. Making the visible element
/// smaller than its target is fine; making the target smaller is the mistake.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({super.key, required this.selected, required this.onChanged});

  final MenuFilter selected;
  final ValueChanged<MenuFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: MenuFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = MenuFilter.values[index];
          return SelectPill(
            label: filter.label,
            isSelected: filter == selected,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }
}

/// Reusable selectable pill. Dark text on saffron when selected, never white.
class SelectPill extends StatelessWidget {
  const SelectPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          height: AppSpacing.minTouchTarget,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: AppSpacing.chipHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.base,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
