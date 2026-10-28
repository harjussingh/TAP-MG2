import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/sample_data.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dish_palette.dart';
import '../widgets/category_tile.dart';
import '../widgets/dish_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/robomos_logo.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'dish_detail_screen.dart';

enum ViewState { loading, ready, error }

/// The menu.
///
/// Laid out as an editorial page rather than a list: the featured bowls get a
/// colour card each so the food is the first thing seen, and the long list sits
/// below for people who already know what they want. Searching or choosing a
/// category collapses the page to results only, because at that point the
/// customer is looking for something specific and the browsing furniture is
/// just in the way.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ViewState _state = ViewState.loading;
  MenuFilter _filter = MenuFilter.all;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    // TODO(api): api.menuItems() once the backend is reachable.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _state = ViewState.ready);
  }

  bool get _isBrowsing => _filter == MenuFilter.all && _search.trim().isEmpty;

  List<Dish> get _visible {
    final query = _search.trim().toLowerCase();
    return kDishes.where((dish) {
      if (!_filter.matches(dish)) return false;
      if (query.isEmpty) return true;
      return dish.name.toLowerCase().contains(query) ||
          dish.ingredients.toLowerCase().contains(query);
    }).toList();
  }

  List<Dish> get _featured =>
      kDishes.where((d) => d.inStock && !d.isCustom).take(4).toList();

  List<Dish> get _popular {
    final sorted = kDishes.where((d) => !d.isCustom).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(6).toList();
  }

  DishPalette _paletteFor(Dish dish, int index) => dish.paletteKey != null
      ? DishPalette.fromKey(dish.paletteKey)
      : DishPalette.forIndex(index);

  void _openDish(Dish dish) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DishDetailScreen(
          dish: dish,
          palette: _paletteFor(dish, kDishes.indexOf(dish)),
        ),
      ),
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CartScreen()),
    );
  }

  Future<void> _pickOrderType() async {
    final state = AppScope.of(context);
    final chosen = await showModalBottomSheet<OrderType>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl,
                  AppSpacing.lg, AppSpacing.sm),
              child:
                  Text('How are you ordering?', style: AppTypography.sectionHeading),
            ),
            for (final type in OrderType.values)
              ListTile(
                minVerticalPadding: AppSpacing.md,
                leading: Icon(
                  type == OrderType.dineIn
                      ? Icons.restaurant
                      : Icons.takeout_dining_outlined,
                  color: AppColors.base,
                ),
                title: Text(type.label, style: AppTypography.body),
                trailing: type == state.orderType
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, type),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) state.setOrderType(chosen);
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _BrandBar(cartCount: state.cart.length, onCartTap: _openCart),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _body(AppState state) {
    switch (_state) {
      case ViewState.loading:
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (_, __) => const DishCardSkeleton(),
        );

      case ViewState.error:
        return ErrorStateView(
          title: "We couldn't load the menu",
          message: 'Check your connection and try again.',
          onRetry: _load,
        );

      case ViewState.ready:
        return RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              _OrderContextRow(
                orderType: state.orderType,
                tableNumber: state.tableNumber,
                onTap: _pickOrderType,
              ),
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                onClear: () => setState(() {
                  _search = '';
                  _searchController.clear();
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              CategoryTileBar(
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              if (_isBrowsing) ..._browsing() else ..._results(),
            ],
          ),
        );
    }
  }

  // ------------------------------------------------------------- browsing

  List<Widget> _browsing() {
    final featured = _featured;
    final popular = _popular;

    return [
      const SizedBox(height: AppSpacing.xl),
      const _Headline(),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        height: 300,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding),
          itemCount: featured.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, i) {
            final dish = featured[i];
            return FeatureCard(
              dish: dish,
              palette: _paletteFor(dish, i),
              onTap: () => _openDish(dish),
            );
          },
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      _SectionHeading(
        title: 'Popular now',
        actionLabel: 'See all',
        onAction: () => setState(() => _filter = MenuFilter.popular),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: 172,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding),
          itemCount: popular.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, i) {
            final dish = popular[i];
            return CompactDishCard(
              dish: dish,
              palette: _paletteFor(dish, i + 2),
              onTap: () => _openDish(dish),
            );
          },
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      const _BuildYourOwnBanner(),
      const SizedBox(height: AppSpacing.xl),
      _SectionHeading(
        title: 'The full menu',
        actionLabel: '${kDishes.length} bowls',
      ),
      const SizedBox(height: AppSpacing.md),
      for (final dish in kDishes)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0,
              AppSpacing.screenPadding, AppSpacing.cardGap),
          child: DishCard(dish: dish, onTap: () => _openDish(dish)),
        ),
    ];
  }

  // -------------------------------------------------------------- results

  List<Widget> _results() {
    final dishes = _visible;

    if (dishes.isEmpty) {
      return [
        SizedBox(
          height: 360,
          child: EmptyStateView(
            icon: Icons.search_off,
            title: 'No bowls match this',
            message: 'Try another category, or clear your search.',
            actionLabel: 'Show everything',
            onAction: () => setState(() {
              _filter = MenuFilter.all;
              _search = '';
              _searchController.clear();
            }),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: AppSpacing.lg),
      _SectionHeading(
        title: _filter == MenuFilter.all ? 'Results' : _filter.label,
        actionLabel: dishes.length == 1 ? '1 bowl' : '${dishes.length} bowls',
      ),
      const SizedBox(height: AppSpacing.md),
      for (final dish in dishes)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0,
              AppSpacing.screenPadding, AppSpacing.cardGap),
          child: DishCard(dish: dish, onTap: () => _openDish(dish)),
        ),
    ];
  }
}

// ----------------------------------------------------------------- pieces

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.cartCount, required this.onCartTap});

  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
      child: Row(
        children: [
          const RobomosLogo(size: 44, onDark: false),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Robomos',
                    style: AppTypography.cardTitle
                        .copyWith(fontWeight: FontWeight.w700, height: 1.1)),
                Text('Poke · Melbourne',
                    style: AppTypography.label
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          _CartButton(count: cartCount, onTap: onCartTap),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? 'Your order, empty' : 'Your order, $count items',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              decoration: BoxDecoration(
                color: count == 0 ? AppColors.card : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                    color: count == 0 ? AppColors.border : AppColors.primary),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 21,
                color: count == 0 ? AppColors.base : AppColors.onPrimary,
              ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text('$count',
                      style: AppTypography.label.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderContextRow extends StatelessWidget {
  const _OrderContextRow({
    required this.orderType,
    required this.tableNumber,
    required this.onTap,
  });

  final OrderType orderType;
  final String tableNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = orderType == OrderType.dineIn && tableNumber.isNotEmpty
        ? '${orderType.label} · Table $tableNumber'
        : orderType.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0,
          AppSpacing.screenPadding, AppSpacing.md),
      child: Semantics(
        button: true,
        label: 'Order type, $summary. Tap to change.',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Container(
            height: AppSpacing.minTouchTarget,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(
                  orderType == OrderType.dineIn
                      ? Icons.restaurant
                      : Icons.takeout_dining_outlined,
                  size: 18,
                  color: AppColors.base,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(summary,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                Text('Change',
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.base),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search bowls, proteins, sauces...',
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                  tooltip: 'Clear search',
                ),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            borderSide: BorderSide(color: AppColors.primary, width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

/// Two weights on two lines, so the page opens with a voice rather than a
/// label. The second line is lighter, which is what keeps it from shouting.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Built by robot.',
              style: AppTypography.screenTitle
                  .copyWith(fontSize: 30, height: 1.15)),
          Text('Made exactly for you.',
              style: AppTypography.screenTitle.copyWith(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: AppTypography.sectionHeading.copyWith(fontSize: 20)),
          ),
          if (actionLabel != null)
            onAction == null
                ? Text(actionLabel!, style: AppTypography.secondary)
                : TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.base,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm)),
                    child: Text(actionLabel!,
                        style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
        ],
      ),
    );
  }
}

/// The custom bowl is the product, so it gets a band of its own rather than
/// sitting in the list as the sixth card down.
class _BuildYourOwnBanner extends StatelessWidget {
  const _BuildYourOwnBanner();

  @override
  Widget build(BuildContext context) {
    final bowl = kDishes.firstWhere((d) => d.isCustom,
        orElse: () => kDishes.first);

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Material(
        color: AppColors.header,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DishDetailScreen(
                dish: bowl,
                palette: DishPalette.fromKey(bowl.paletteKey),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text('THE FISHBOWL',
                            style: AppTypography.label.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onPrimary)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Build your own bowl',
                          style: AppTypography.sectionHeading
                              .copyWith(color: AppColors.onHeader)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Six steps. The machine builds it exactly to spec.',
                        style: AppTypography.secondary.copyWith(
                            color:
                                AppColors.onHeader.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Text('Start building',
                              style: AppTypography.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(Icons.arrow_forward,
                              size: 17, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text('\u{1F963}', style: TextStyle(fontSize: 64)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
