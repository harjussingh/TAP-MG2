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
  });

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
}
