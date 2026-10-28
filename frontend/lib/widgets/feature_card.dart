import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dish_palette.dart';
import 'dish_card.dart';

/// The large colour card in the featured carousel.
///
/// The dish sits on a wash of its own colour, with the name and description on
/// the solid block beneath. Giving each card its own hue is what makes a row
/// of food read as food rather than as a list, and it is the one place the app
/// uses colour decoratively rather than to carry meaning.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.dish,
    required this.palette,
    this.onTap,
    this.width = 232,
  });

  final Dish dish;
  final DishPalette palette;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final unavailable = !dish.inStock;

    return Semantics(
      button: true,
      label: '${dish.name}, ${dish.formattedPrice}'
          '${unavailable ? ', out of stock' : ''}',
      child: Opacity(
        opacity: unavailable ? 0.55 : 1,
        child: SizedBox(
          width: width,
          child: Material(
            color: palette.colour,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: unavailable ? null : onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(dish: dish, palette: palette, unavailable: unavailable),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stars(rating: dish.rating, onColour: palette.onColour),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          dish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle
                              .copyWith(color: palette.onColour, height: 1.2),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dish.sauce.isEmpty
                              ? dish.ingredients
                              : '${dish.ingredients} · ${dish.sauce}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.secondary.copyWith(
                              color: palette.onColour.withValues(alpha: 0.82)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Text(
                              dish.formattedPrice,
                              style: AppTypography.cardTitle.copyWith(
                                  color: palette.onColour,
                                  fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: palette.onColour.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_forward,
                                  size: 17, color: palette.onColour),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.dish,
    required this.palette,
    required this.unavailable,
  });

  final Dish dish;
  final DishPalette palette;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      width: double.infinity,
      color: palette.wash,
      child: Stack(
        children: [
          Center(child: Text(dish.emoji, style: const TextStyle(fontSize: 62))),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final tag in dish.tags.take(2))
                  _Pill(label: tag.label),
                if (unavailable)
                  const _Pill(label: 'Out of stock', colour: AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.colour});

  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final background = colour ?? AppColors.card;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          color: colour == null ? AppColors.base : Colors.white,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.onColour});

  final double rating;
  final Color onColour;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: onColour.withValues(alpha: i <= rating.round() ? 1 : 0.45),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.label
              .copyWith(color: onColour.withValues(alpha: 0.9)),
        ),
      ],
    );
  }
}

/// The small card in the "Popular now" row: a square image tile with the name
/// and price beneath, so more of the menu is visible at a glance.
class CompactDishCard extends StatelessWidget {
  const CompactDishCard({
    super.key,
    required this.dish,
    required this.palette,
    this.onTap,
  });

  final Dish dish;
  final DishPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final unavailable = !dish.inStock;

    return Opacity(
      opacity: unavailable ? 0.55 : 1,
      child: SizedBox(
        width: 136,
        child: InkWell(
          onTap: unavailable ? null : onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 104,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.wash,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: Text(dish.emoji, style: const TextStyle(fontSize: 42)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                dish.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(dish.formattedPrice,
                      style: AppTypography.secondary
                          .copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.star_rounded,
                      size: 13, color: AppColors.primary),
                  Text(dish.rating.toStringAsFixed(1),
                      style: AppTypography.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown after something is added, so the confirmation is unmissable without
/// stealing the screen the way a full page would.
Future<void> showAddedToCart(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String emoji,
  required VoidCallback onViewCart,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmojiTile(emoji: emoji, colour: AppColors.tileBlue, size: 72),
            const SizedBox(height: AppSpacing.lg),
            Text('Added to your order', style: AppTypography.sectionHeading),
            const SizedBox(height: AppSpacing.xs),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center, style: AppTypography.secondary),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onViewCart();
                },
                child: const Text('View my order'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Keep browsing'),
            ),
          ],
        ),
      ),
    ),
  );
}
