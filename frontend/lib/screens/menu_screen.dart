import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/sample_data.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/robomos_logo.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'dish_detail_screen.dart';

enum ViewState { loading, ready, error }

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ViewState _state = ViewState.loading;
  MenuFilter _filter = MenuFilter.all;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    // Replace with the API call once the backend is running.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _state = ViewState.ready);
  }

  /// Search and filters narrow together rather than overriding each other,
  /// which is what people expect when both are on screen.
  List<Dish> get _visible {
    final query = _search.trim().toLowerCase();
    return kDishes.where((dish) {
      if (!_filter.matches(dish)) return false;
      if (query.isEmpty) return true;
      return dish.name.toLowerCase().contains(query) ||
          dish.ingredients.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _pickOrderType() async {
    final state = AppScope.of(context);
    final chosen = await showModalBottomSheet<OrderType>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl,
                  AppSpacing.lg, AppSpacing.sm),
              child: Text('How are you ordering?',
                  style: AppTypography.sectionHeading),
            ),
            for (final type in OrderType.values)
              ListTile(
                minVerticalPadding: AppSpacing.md,
                title: Text(type.label, style: AppTypography.body),
                trailing: type == state.orderType
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, type),
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
    return Column(
      children: [
        _Header(
          orderType: state.orderType,
          tableNumber: state.tableNumber,
          cartCount: state.cart.length,
          onOrderTypeTap: _pickOrderType,
          onSearchChanged: (v) => setState(() => _search = v),
          onCartTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilterChipBar(
          selected: _filter,
          onChanged: (v) => setState(() => _filter = v),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
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
        final dishes = _visible;
        if (dishes.isEmpty) {
          return EmptyStateView(
            icon: Icons.search_off,
            title: 'No bowls match this filter',
            message: 'Try a different filter, or clear your search.',
            actionLabel: 'Show all bowls',
            onAction: () => setState(() {
              _filter = MenuFilter.all;
              _search = '';
            }),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
              AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xxxl),
          itemCount: dishes.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  dishes.length == 1 ? '1 bowl' : '${dishes.length} bowls',
                  style: AppTypography.secondary,
                ),
              );
            }
            final dish = dishes[index - 1];
            return DishCard(
              dish: dish,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => DishDetailScreen(dish: dish)),
              ),
            );
          },
        );
    }
  }
}

/// The dark header. The order type is a compact summary rather than a
/// full-width selector, so the first dish is visible without scrolling.
class _Header extends StatelessWidget {
  const _Header({
    required this.orderType,
    required this.tableNumber,
    required this.cartCount,
    required this.onOrderTypeTap,
    required this.onSearchChanged,
    required this.onCartTap,
  });

  final OrderType orderType;
  final String tableNumber;
  final int cartCount;
  final VoidCallback onOrderTypeTap;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final summary = orderType == OrderType.dineIn && tableNumber.isNotEmpty
        ? '${orderType.label} \u00b7 Table $tableNumber'
        : orderType.label;

    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0,
          AppSpacing.screenPadding, AppSpacing.lg),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text('ROBOMOS POKE \u00b7 MELBOURNE',
                style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, letterSpacing: 1.6)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  // The mark is drawn rather than an emoji: the system robot
                  // emoji is a different design on every phone and did not
                  // match the logo on the entry screens.
                  child: Row(
                    children: [
                      Flexible(
                        child: Text("What's it today?",
                            style: AppTypography.screenTitle
                                .copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const RobomosLogo(size: 26, badge: false),
                    ],
                  ),
                ),
                _CartButton(count: cartCount, onTap: onCartTap),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: 'Order type, $summary. Tap to change.',
              child: InkWell(
                onTap: onOrderTypeTap,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: Container(
                  height: AppSpacing.minTouchTarget,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(summary,
                          style:
                              AppTypography.body.copyWith(color: Colors.white)),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: onSearchChanged,
              style: AppTypography.body.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search bowls...',
                hintStyle:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
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
    SettingsScope.watch(context);
    return Semantics(
      button: true,
      label: count == 0 ? 'Cart, empty' : 'Cart, $count items',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          height: AppSpacing.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: count == 0
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 20,
                  color: count == 0 ? Colors.white : AppColors.base),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('$count',
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
