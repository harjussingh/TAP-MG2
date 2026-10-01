import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DishCard extends StatelessWidget {
  const DishCard({super.key, required this.dish, this.onTap});

  final Dish dish;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final unavailable = !dish.inStock;

    return Semantics(
      button: true,
      label: '${dish.name}, ${dish.formattedPrice}'
          '${unavailable ? ', out of stock' : ''}',
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          onTap: unavailable ? null : onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Opacity(
            opacity: unavailable ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Tags(dish: dish, unavailable: unavailable),
                        const SizedBox(height: AppSpacing.sm),
                        Text(dish.name, style: AppTypography.cardTitle),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dish.sauce.isEmpty
                              ? dish.ingredients
                              : '${dish.ingredients} \u00b7 ${dish.sauce}',
                          style: AppTypography.secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              dish.formattedPrice,
                              style: AppTypography.cardTitle
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (dish.kilojoules > 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(formatKilojoules(dish.kilojoules),
                                  style: AppTypography.secondary),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  EmojiTile(emoji: dish.emoji, colour: dish.tileColour),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.dish, required this.unavailable});

  final Dish dish;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final chips = <Widget>[
      for (final tag in dish.tags) _TagPill(label: tag.label),
      if (unavailable)
        const _TagPill(label: 'Out of stock', colour: AppColors.error),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: chips);
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.colour});

  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colour == null
            ? AppColors.surface
            : colour!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: colour ?? AppColors.border),
      ),
      child: Text(label,
          style: AppTypography.label.copyWith(color: colour ?? AppColors.base)),
    );
  }
}

/// The tinted square holding a food emoji. Replace with Image.asset when
/// real photography is available; the tile reserves the same space either way.
class EmojiTile extends StatelessWidget {
  const EmojiTile({
    super.key,
    required this.emoji,
    required this.colour,
    this.size = AppSpacing.thumbnailSize,
  });

  final String emoji;
  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.42)),
    );
  }
}

String formatKilojoules(int kj) {
  final digits = kj.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer kJ';
}

String formatPrice(double value) => '\$${value.toStringAsFixed(2)}';
