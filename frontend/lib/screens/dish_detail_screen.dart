import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dish_palette.dart';
import '../widgets/dish_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/quantity_stepper.dart';
import 'bowl_builder_screen.dart';
import 'cart_screen.dart';

/// One dish, full screen.
///
/// The food sits on a full-bleed panel of the dish's own colour, with the
/// detail sheet curving over it. Putting the picture first and the words second
/// is the whole point of a menu, and the curve is what stops the sheet reading
/// as a card dropped on a background.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({
    super.key,
    required this.dish,
    required this.palette,
  });

  final Dish dish;
  final DishPalette palette;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _quantity = 1;
  bool _saved = false;

  Dish get dish => widget.dish;

  double get _lineTotal => dish.price * _quantity;

  void _addToCart() {
    final state = AppScope.of(context);
    for (var i = 0; i < _quantity; i++) {
      state.addToCart(CartLine(
        title: dish.name,
        subtitle: dish.sauce.isEmpty
            ? dish.ingredients
            : '${dish.ingredients} · ${dish.sauce}',
        emoji: dish.emoji,
        price: dish.price,
        kilojoules: dish.kilojoules,
      ));
    }

    showAddedToCart(
      context,
      title: _quantity == 1 ? dish.name : '${dish.name} × $_quantity',
      subtitle: formatPrice(_lineTotal),
      emoji: dish.emoji,
      onViewCart: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CartScreen()),
        );
      },
    );
  }

  void _openBuilder() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BowlBuilderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    // Saving a bowl needs an account, so a guest never sees the save control.
    final isMember = AppScope.of(context).isMember;

    return Scaffold(
      // The sheet's rounded top corners reveal this background in two small
      // wedges. The hero fades to palette.wash at its bottom edge, so the
      // background must be that same wash (not the saturated palette.colour)
      // for the corners to blend seamlessly into the hero on both sides.
      backgroundColor: widget.palette.wash,
      body: Column(
        children: [
          _Hero(
            dish: dish,
            palette: widget.palette,
            saved: _saved,
            onBack: () => Navigator.pop(context),
            onSave: () => setState(() => _saved = !_saved),
            showSave: isMember,
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusSheet)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusSheet)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                      AppSpacing.xl, AppSpacing.screenPadding, AppSpacing.xl),
                  children: [
                    _TitleBlock(dish: dish),
                    const SizedBox(height: AppSpacing.lg),
                    _PriceRow(
                      total: _lineTotal,
                      isCustom: dish.isCustom,
                      quantity: _quantity,
                      onQuantity: (v) => setState(() => _quantity = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('About this bowl',
                        style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(dish.description,
                        style: AppTypography.body.copyWith(height: 1.55)),
                    const SizedBox(height: AppSpacing.xl),
                    _FactStrip(dish: dish),
                    const SizedBox(height: AppSpacing.lg),
                    _AllergenNote(dish: dish),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        dish: dish,
        total: _lineTotal,
        saved: _saved,
        onSave: () => setState(() => _saved = !_saved),
        onPrimary: dish.isCustom ? _openBuilder : _addToCart,
        showSave: isMember,
      ),
    );
  }
}

// ----------------------------------------------------------------- pieces

class _Hero extends StatelessWidget {
  const _Hero({
    required this.dish,
    required this.palette,
    required this.saved,
    required this.onBack,
    required this.onSave,
    required this.showSave,
  });

  final Dish dish;
  final DishPalette palette;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool showSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 264,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.colour, palette.wash],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Text(dish.emoji, style: const TextStyle(fontSize: 128)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: onBack,
                    tooltip: 'Back',
                    onColour: palette.onColour,
                  ),
                  if (showSave)
                    _RoundButton(
                      icon: saved ? Icons.favorite : Icons.favorite_border,
                      onTap: onSave,
                      tooltip: saved ? 'Remove from saved' : 'Save this bowl',
                      onColour: palette.onColour,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.onColour,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color onColour;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          decoration: BoxDecoration(
            color: onColour.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: onColour),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dish.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in dish.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(tag.label, style: AppTypography.label),
                  ),
              ],
            ),
          ),
        Text(dish.name,
            style: AppTypography.screenTitle.copyWith(height: 1.15)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= dish.rating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(dish.rating.toStringAsFixed(1),
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: AppSpacing.xs),
            if (dish.reviewCount > 0)
              Text('(${dish.reviewCount} reviews)',
                  style: AppTypography.secondary),
          ],
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.total,
    required this.isCustom,
    required this.quantity,
    required this.onQuantity,
  });

  final double total;
  final bool isCustom;
  final int quantity;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isCustom ? 'Starts at' : 'Price',
                style: AppTypography.secondary),
            Text(formatPrice(total),
                style: AppTypography.screenTitle.copyWith(fontSize: 26)),
          ],
        ),
        const Spacer(),
        // A custom bowl is priced inside the builder, so a quantity here
        // would be meaningless.
        if (!isCustom)
          QuantityStepper(value: quantity, onChanged: onQuantity),
      ],
    );
  }
}

class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Fact(
            label: 'ENERGY',
            value: dish.isCustom ? 'Varies' : formatKilojoules(dish.kilojoules),
          ),
          _Divider(),
          _Fact(label: 'PREP', value: dish.isCustom ? '4-6 min' : '~4 min'),
          _Divider(),
          _Fact(label: 'MADE BY', value: 'Machine 2'),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.1)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.border,
    );
  }
}

class _AllergenNote extends StatelessWidget {
  const _AllergenNote({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.tileCream,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALLERGENS',
                    style: AppTypography.label.copyWith(
                        letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  dish.isCustom
                      ? 'Varies with what you choose. Every ingredient is '
                          'labelled in the builder.'
                      : 'Contains fish, soy and sesame. Prepared in a kitchen '
                          'that handles all major allergens.',
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.dish,
    required this.total,
    required this.saved,
    required this.onSave,
    required this.onPrimary,
    required this.showSave,
  });

  final Dish dish;
  final double total;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onPrimary;
  final bool showSave;

  @override
  Widget build(BuildContext context) {
    final unavailable = !dish.inStock;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Row(
            children: [
              if (showSave) ...[
                InkWell(
                  onTap: onSave,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: AppSpacing.buttonHeight,
                    height: AppSpacing.buttonHeight,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      saved ? Icons.favorite : Icons.favorite_border,
                      color: saved ? AppColors.error : AppColors.base,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: unavailable ? null : onPrimary,
                  child: Text(
                    unavailable
                        ? 'Out of stock'
                        : dish.isCustom
                            ? 'Start building'
                            : 'Add · ${formatPrice(total)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
