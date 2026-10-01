import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import 'bowl_builder_screen.dart';
import 'cart_screen.dart';

class DishDetailScreen extends StatelessWidget {
  const DishDetailScreen({super.key, required this.dish});

  final Dish dish;

  void _addToCart(BuildContext context) {
    AppScope.of(context).addToCart(CartLine(
      title: dish.name,
      subtitle: '${dish.ingredients} \u00b7 ${dish.sauce}',
      emoji: dish.emoji,
      price: dish.price,
      kilojoules: dish.kilojoules,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${dish.name} added to your order')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('MENU',
            style: AppTypography.label
                .copyWith(color: Colors.white, letterSpacing: 1.4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 200,
            color: dish.tileColour,
            alignment: Alignment.center,
            child: Text(dish.emoji, style: const TextStyle(fontSize: 76)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dish.tags.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final t in dish.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.tileBlue,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(t.label, style: AppTypography.label),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(dish.name, style: AppTypography.screenTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dish.isCustom
                      ? 'Take the wheel. Pick your base, load your protein, stack '
                          'your vegetables, and let the machine build it exactly to spec.'
                      : '${dish.ingredients} with ${dish.sauce.toLowerCase()}.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('INGREDIENTS',
                    style: AppTypography.label
                        .copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
                const SizedBox(height: AppSpacing.sm),
                Text(dish.ingredients, style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.tileCream,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALLERGENS',
                                style: AppTypography.label.copyWith(
                                    color: AppColors.primary, letterSpacing: 1.2)),
                            Text(
                              dish.isCustom
                                  ? 'Varies by selection'
                                  : 'Contains fish, soy and sesame',
                              style: AppTypography.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Energy', style: AppTypography.secondary),
                        Text(
                          dish.isCustom
                              ? 'Varies'
                              : formatKilojoules(dish.kilojoules),
                          style: AppTypography.body,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Price', style: AppTypography.secondary),
                        Text(dish.formattedPrice,
                            style: AppTypography.screenTitle),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: ElevatedButton(
            onPressed: dish.isCustom
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const BowlBuilderScreen()),
                    )
                : () => _addToCart(context),
            child: Text(dish.isCustom ? 'Build my bowl' : 'Add to order'),
          ),
        ),
      ),
    );
  }
}
