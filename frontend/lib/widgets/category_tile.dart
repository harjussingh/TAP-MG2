import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The square category tiles across the top of the menu.
///
/// Replaces the pill chips. A tile with a glyph above its label is quicker to
/// hit on a phone and reads as a category rather than a filter switch, which
/// matters because this is the first control a customer touches.
class CategoryTileBar extends StatelessWidget {
  const CategoryTileBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MenuFilter selected;
  final ValueChanged<MenuFilter> onChanged;

  static const _glyphs = {
    MenuFilter.all: '\u{1F963}',
    MenuFilter.popular: '\u{2B50}',
    MenuFilter.vegan: '\u{1F966}',
    MenuFilter.glutenFree: '\u{1F33E}',
    MenuFilter.custom: '\u{1F962}',
  };

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: MenuFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final filter = MenuFilter.values[i];
          return _Tile(
            glyph: _glyphs[filter] ?? '\u{1F963}',
            label: filter.label,
            isSelected: filter == selected,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.glyph,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(glyph, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  // Dark on saffron, never white: the contrast rule holds
                  // because onPrimary comes from the chosen accent.
                  color: isSelected ? AppColors.onPrimary : AppColors.base,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
