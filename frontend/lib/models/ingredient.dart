import '../services/api_models.dart';
import 'food_emoji.dart';

enum IngredientKind { base, protein, vegetable, sauce, topping }

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kind,
    this.price = 0,
    this.kilojoules = 0,
    this.inStock = true,
    this.apiId = '',
    this.groupKey = '',
  });

  /// One choice in one of the menu item's option groups, as the server sent it.
  factory Ingredient.fromOption(
          MenuOption o, OptionGroup group, IngredientKind kind) =>
      Ingredient(
        id: slugOf(o.name),
        name: o.name,
        emoji: foodEmoji(o.name),
        kind: kind,
        price: o.priceCents / 100,
        kilojoules: caloriesToKilojoules(o.calories),
        inStock: o.isAvailable,
        apiId: o.ingredientId,
        groupKey: group.key,
      );

  /// Readable id from the name ("brown-rice"); keys the curated colours.
  final String id;
  final String name;
  final String emoji;
  final IngredientKind kind;

  /// Added to the bowl's base price.
  final double price;
  final int kilojoules;

  /// False when the machine is not currently loaded with this ingredient.
  /// The interface shows these rather than hiding them, so the customer
  /// understands why a choice is unavailable.
  final bool inStock;

  /// The server's ingredient id and the option group it was offered in.
  /// These are what the order sends; the name is only for people.
  final String apiId;
  final String groupKey;

  int get priceCents => (price * 100).round();

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.apiId == apiId &&
      other.groupKey == groupKey &&
      other.id == id;

  @override
  int get hashCode => Object.hash(apiId, groupKey, id);
}

/// Which builder step an option group belongs to, read from its key
/// (base, protein, veggies, sauce, topping on the seeded menu).
IngredientKind? kindForGroup(OptionGroup g) {
  final k = '${g.key} ${g.name}'.toLowerCase();
  if (k.contains('base')) return IngredientKind.base;
  if (k.contains('protein')) return IngredientKind.protein;
  if (k.contains('veg')) return IngredientKind.vegetable;
  if (k.contains('sauce')) return IngredientKind.sauce;
  if (k.contains('top')) return IngredientKind.topping;
  return null;
}
