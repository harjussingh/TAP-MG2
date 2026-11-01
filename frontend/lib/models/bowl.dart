import '../services/api_models.dart';
import 'ingredient.dart';

/// A customer's bowl in progress.
///
/// The steps and their choices come from the server: the build-your-own menu
/// item's option groups (base, protein, veggies, sauce, toppings). The price
/// shown while building is the item's base price plus each option's price,
/// which is exactly the sum the server makes; the cart then shows the
/// server's own figure.
///
/// The machine has a physical capacity, so [isOverCapacity] is a real
/// constraint rather than a validation nicety.
class Bowl {
  Bowl([this.item]);

  /// Rebuilds a saved recipe against the current menu, so prices and stock
  /// are today's rather than the day it was saved.
  factory Bowl.fromRecipe(SavedRecipe recipe, MenuItem item) {
    final bowl = Bowl(item)
      ..name = recipe.name
      ..recipeId = recipe.id
      ..spice = spiceFromNote(recipe.specialInstructions);
    for (final s in recipe.selections) {
      final match =
          bowl.optionsFor(s.groupKey).where((i) => i.apiId == s.ingredientId);
      if (match.isEmpty) continue;
      bowl._choose(match.first);
    }
    return bowl;
  }

  static const int maxItems = 8;

  /// The build-your-own menu item this bowl is made from.
  final MenuItem? item;

  /// Set once the bowl has been saved to the account.
  String? recipeId;

  /// What the customer called this bowl. Empty until they save it and name
  /// it, so the builder itself never has to show a name.
  String name = '';

  Ingredient? base;
  Ingredient? protein;
  final List<Ingredient> vegetables = [];
  Ingredient? sauce;

  /// 0 = mild, 3 = extra hot. Sent to the kitchen as a note on the line.
  int spice = 0;

  final List<Ingredient> toppings = [];

  // ------------------------------------------------------- server's options

  List<OptionGroup> get _groups => item?.optionGroups ?? const [];

  OptionGroup? _group(IngredientKind kind) {
    for (final g in _groups) {
      if (kindForGroup(g) == kind) return g;
    }
    return null;
  }

  List<Ingredient> _options(IngredientKind kind) {
    final g = _group(kind);
    if (g == null) return const [];
    return [for (final o in g.options) Ingredient.fromOption(o, g, kind)];
  }

  List<Ingredient> optionsFor(String groupKey) {
    for (final g in _groups) {
      if (g.key == groupKey) {
        final kind = kindForGroup(g);
        if (kind == null) return const [];
        return [for (final o in g.options) Ingredient.fromOption(o, g, kind)];
      }
    }
    return const [];
  }

  List<Ingredient> get bases => _options(IngredientKind.base);
  List<Ingredient> get proteins => _options(IngredientKind.protein);
  List<Ingredient> get vegetableOptions => _options(IngredientKind.vegetable);
  List<Ingredient> get sauces => _options(IngredientKind.sauce);
  List<Ingredient> get toppingOptions => _options(IngredientKind.topping);

  int get maxVegetables => _group(IngredientKind.vegetable)?.maxSelect ?? 5;
  int get maxToppings => _group(IngredientKind.topping)?.maxSelect ?? 4;

  void _choose(Ingredient i) {
    switch (i.kind) {
      case IngredientKind.base:
        base = i;
      case IngredientKind.protein:
        protein = i;
      case IngredientKind.vegetable:
        if (!vegetables.contains(i)) vegetables.add(i);
      case IngredientKind.sauce:
        sauce = i;
      case IngredientKind.topping:
        if (!toppings.contains(i)) toppings.add(i);
    }
  }

  // ---------------------------------------------------------------- totals

  List<Ingredient> get all => [
        if (base != null) base!,
        if (protein != null) protein!,
        ...vegetables,
        if (sauce != null) sauce!,
        ...toppings,
      ];

  int get itemCount => all.length;

  bool get isOverCapacity => itemCount > maxItems;

  int get basePriceCents => item?.basePriceCents ?? 0;

  int get priceCents =>
      all.fold(basePriceCents, (sum, i) => sum + i.priceCents);

  double get price => priceCents / 100;

  int get kilojoules => all.fold(caloriesToKilojoules(item?.calories ?? 0),
      (sum, i) => sum + i.kilojoules);

  String get spiceLabel => const ['Mild', 'Medium', 'Hot', 'Extra hot'][spice];

  /// Shown on the cart line, for example "White Rice · Salmon · Sriracha Mayo".
  String get summary {
    final menuItem = item;
    if (menuItem != null && !menuItem.isCustomBowl) return menuItem.name;
    final parts = [
      if (base != null) base!.name,
      if (protein != null) protein!.name,
      if (sauce != null) sauce!.name,
    ];
    return parts.isEmpty ? 'Custom bowl' : parts.join(' · ');
  }

  int get prepMinutes => 4 + (itemCount ~/ 3);

  /// What the server receives: one selection per chosen ingredient.
  List<Selection> toSelections() => [
        for (final i in all)
          Selection(groupKey: i.groupKey, ingredientId: i.apiId),
      ];

  /// The note the kitchen sees on the line. Mild is the default, so it is
  /// only sent when the customer asked for more heat.
  String? get specialInstructions => spice == 0 ? null : 'Spice: $spiceLabel';

  /// What to show in a list. Falls back to the ingredients rather than to a
  /// position, so two unnamed recipes never look identical.
  String get displayName => name.trim().isEmpty ? _suggestedName : name.trim();

  /// A first guess at a name, offered when the customer saves.
  String get _suggestedName {
    if (protein == null && base == null) return 'Custom bowl';
    final parts = [
      if (protein != null) protein!.name,
      if (base != null) base!.name,
    ];
    return parts.join(' on ');
  }

  String get suggestedName => _suggestedName;

  Bowl copy() {
    final b = Bowl(item)
      ..name = name
      ..recipeId = recipeId
      ..base = base
      ..protein = protein
      ..sauce = sauce
      ..spice = spice;
    b.vegetables.addAll(vegetables);
    b.toppings.addAll(toppings);
    return b;
  }
}

/// Reads "Spice: Hot" back from a saved recipe's kitchen note.
int spiceFromNote(String? note) {
  if (note == null) return 0;
  const labels = ['Mild', 'Medium', 'Hot', 'Extra hot'];
  for (var i = labels.length - 1; i >= 0; i--) {
    if (note.contains('Spice: ${labels[i]}')) return i;
  }
  return 0;
}
