import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/sample_data.dart';
import '../models/bowl.dart';
import '../models/ingredient.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/step_progress.dart';
import 'cart_screen.dart';

/// The six-step flow. This is the core of the product: what the customer
/// assembles here is the instruction the machine receives, which is why the
/// last step requires explicit confirmation before anything is sent.
class BowlBuilderScreen extends StatefulWidget {
  const BowlBuilderScreen({super.key});

  @override
  State<BowlBuilderScreen> createState() => _BowlBuilderScreenState();
}

class _BowlBuilderScreenState extends State<BowlBuilderScreen> {
  final Bowl _bowl = Bowl();
  int _step = 1;

  static const _titles = [
    'Base',
    'Protein',
    'Vegetables',
    'Sauce and spice',
    'Toppings',
    'Review',
  ];

  bool get _canAdvance {
    switch (_step) {
      case 1:
        return _bowl.base != null;
      case 2:
        return _bowl.protein != null;
      case 4:
        return _bowl.sauce != null;
      default:
        return true;
    }
  }

  void _next() {
    if (_step < 6) setState(() => _step++);
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _surpriseMe() {
    final rng = Random();
    setState(() {
      _bowl.base = kBases[rng.nextInt(kBases.length)];
      final proteins = kProteins.where((i) => i.inStock).toList();
      _bowl.protein = proteins[rng.nextInt(proteins.length)];
      _bowl.vegetables
        ..clear()
        ..addAll((kVegetables.where((i) => i.inStock).toList()..shuffle(rng))
            .take(2));
      _bowl.sauce = kSauces[rng.nextInt(kSauces.length)];
      _bowl.spice = rng.nextInt(4);
      _bowl.toppings.clear();
      _step = 6;
    });
  }

  void _sendToMachine() {
    final state = AppScope.of(context);
    state.addToCart(CartLine(
      title: 'Build Your Own Bowl',
      subtitle: _bowl.summary,
      emoji: '\u{1F963}',
      price: _bowl.price,
      kilojoules: _bowl.kilojoules,
      isCustom: true,
    ));
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  StepProgress(current: _step),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('STEP $_step OF 6',
                                style: AppTypography.label.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2)),
                            Text(_titles[_step - 1],
                                style: AppTypography.screenTitle),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _surpriseMe,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.base,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                        ),
                        child: const Text('\u{1F3B2} Surprise me'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BowlSummaryBar(bowl: _bowl, step: _step),
                  if (_bowl.isOverCapacity) ...[
                    const SizedBox(height: AppSpacing.md),
                    _CapacityWarning(),
                  ],
                ],
              ),
            ),
            Expanded(child: _stepBody()),
            _BottomBar(
              bowl: _bowl,
              step: _step,
              canAdvance: _canAdvance && !_bowl.isOverCapacity,
              onNext: _step == 6 ? _sendToMachine : _next,
              onBack: _back,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 1:
        return _PickOne(
          hint: 'Choose your base \u2014 it goes down first.',
          options: kBases,
          selected: _bowl.base,
          onSelect: (i) => setState(() => _bowl.base = i),
        );
      case 2:
        return Column(
          children: [
            Expanded(
              child: _PickOne(
                hint: 'Pick your protein.',
                options: kProteins,
                selected: _bowl.protein,
                onSelect: (i) => setState(() => _bowl.protein = i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: SwitchListTile.adaptive(
                value: _bowl.largePortion,
                onChanged: (v) => setState(() => _bowl.largePortion = v),
                title: Text('Large portion', style: AppTypography.body),
                subtitle: Text('Adds \$3.50', style: AppTypography.secondary),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      case 3:
        return _PickMany(
          hint: 'Add up to ${Bowl.maxVegetables} vegetables.',
          options: kVegetables,
          selected: _bowl.vegetables,
          max: Bowl.maxVegetables,
          onToggle: (i) => setState(() {
            if (_bowl.vegetables.contains(i)) {
              _bowl.vegetables.remove(i);
            } else if (_bowl.vegetables.length < Bowl.maxVegetables) {
              _bowl.vegetables.add(i);
            }
          }),
        );
      case 4:
        return Column(
          children: [
            Expanded(
              child: _PickOne(
                hint: 'Choose a sauce.',
                options: kSauces,
                selected: _bowl.sauce,
                onSelect: (i) => setState(() => _bowl.sauce = i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spice level: ${_bowl.spiceLabel}',
                      style: AppTypography.body),
                  Slider(
                    value: _bowl.spice.toDouble(),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    activeColor: AppColors.primary,
                    label: _bowl.spiceLabel,
                    onChanged: (v) => setState(() => _bowl.spice = v.round()),
                  ),
                ],
              ),
            ),
          ],
        );
      case 5:
        return _PickMany(
          hint: 'Toppings are optional.',
          options: kToppings,
          selected: _bowl.toppings,
          max: 4,
          onToggle: (i) => setState(() {
            if (_bowl.toppings.contains(i)) {
              _bowl.toppings.remove(i);
            } else {
              _bowl.toppings.add(i);
            }
          }),
        );
      default:
        return _Review(
          bowl: _bowl,
          onEdit: (step) => setState(() => _step = step),
          onSave: () {
            AppScope.of(context).saveBowl(_bowl);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved to your recipes')),
            );
          },
        );
    }
  }
}

class _BowlSummaryBar extends StatelessWidget {
  const _BowlSummaryBar({required this.bowl, required this.step});

  final Bowl bowl;
  final int step;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final count = bowl.itemCount;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.border, shape: BoxShape.circle),
          child: Text(count == 0 ? '\u{1F963}' : '\u{1F957}',
              style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    count == 0
                        ? 'Empty bowl'
                        : '$count ingredient${count == 1 ? '' : 's'} added',
                    style: AppTypography.body,
                  ),
                  Text('Step $step of 6', style: AppTypography.secondary),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: step / 6,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CapacityWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Bowl is full \u2014 remove an ingredient',
                style: AppTypography.secondary
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _PickOne extends StatelessWidget {
  const _PickOne({
    required this.hint,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String hint;
  final List<Ingredient> options;
  final Ingredient? selected;
  final ValueChanged<Ingredient> onSelect;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        Text(hint, style: AppTypography.body),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.15,
          children: [
            for (final option in options)
              _IngredientTile(
                ingredient: option,
                isSelected: option.id == selected?.id,
                onTap: () => onSelect(option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _PickMany extends StatelessWidget {
  const _PickMany({
    required this.hint,
    required this.options,
    required this.selected,
    required this.max,
    required this.onToggle,
  });

  final String hint;
  final List<Ingredient> options;
  final List<Ingredient> selected;
  final int max;
  final ValueChanged<Ingredient> onToggle;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(hint, style: AppTypography.body)),
            Text('${selected.length} of $max selected',
                style: AppTypography.secondary),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.15,
          children: [
            for (final option in options)
              _IngredientTile(
                ingredient: option,
                isSelected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Out of stock ingredients are shown rather than hidden, so the customer
/// understands why a choice is not available.
class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    required this.ingredient,
    required this.isSelected,
    required this.onTap,
  });

  final Ingredient ingredient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final disabled = !ingredient.inStock;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ingredient.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: AppSpacing.sm),
                Text(ingredient.name,
                    textAlign: TextAlign.center, style: AppTypography.label),
                if (ingredient.price > 0)
                  Text('+${formatPrice(ingredient.price)}',
                      style: AppTypography.secondary),
                if (disabled)
                  Text('Out of stock',
                      style: AppTypography.label
                          .copyWith(color: AppColors.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({required this.bowl, required this.onEdit, required this.onSave});

  final Bowl bowl;
  final ValueChanged<int> onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    Widget row(String label, String value, int step) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary, letterSpacing: 1.2)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(value, style: AppTypography.body),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onEdit(step),
                child: Text('Edit',
                    style: AppTypography.body.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        Text('Looks good? Tap any section to edit before sending.',
            style: AppTypography.body),
        const SizedBox(height: AppSpacing.lg),
        row('Base', bowl.base?.name ?? 'Not chosen', 1),
        row('Protein',
            '${bowl.protein?.name ?? 'Not chosen'} \u00b7 ${bowl.largePortion ? 'Large' : 'Regular'}',
            2),
        row(
            'Vegetables',
            bowl.vegetables.isEmpty
                ? 'None'
                : bowl.vegetables.map((v) => v.name).join(', '),
            3),
        row('Sauce', '${bowl.sauce?.name ?? 'Not chosen'} \u00b7 ${bowl.spiceLabel}', 4),
        row('Toppings',
            bowl.toppings.isEmpty
                ? 'None'
                : bowl.toppings.map((t) => t.name).join(', '),
            5),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _Stat(label: 'TOTAL', value: formatPrice(bowl.price)),
              _Stat(label: 'ENERGY', value: formatKilojoules(bowl.kilojoules)),
              _Stat(label: 'PREP TIME', value: '${bowl.prepMinutes} min'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onSave,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
            foregroundColor: AppColors.base,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
          ),
          child: const Text('Save as my recipe'),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.1)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.cardTitle),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bowl,
    required this.step,
    required this.canAdvance,
    required this.onNext,
    required this.onBack,
  });

  final Bowl bowl;
  final int step;
  final bool canAdvance;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final isLast = step == 6;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatPrice(bowl.price), style: AppTypography.cardTitle),
              Text(formatKilojoules(bowl.kilojoules),
                  style: AppTypography.secondary),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 190,
            child: ElevatedButton(
              // Disabled until the step's required choice is made.
              onPressed: canAdvance ? onNext : null,
              style: isLast
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white)
                  : null,
              child: Text(isLast ? '\u{1F916} Send to machine' : 'Next \u2192'),
            ),
          ),
        ],
      ),
    );
  }
}
