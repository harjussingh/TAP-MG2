import 'ingredient.dart';

/// A customer's bowl in progress.
///
/// The machine has a physical capacity, so [isOverCapacity] is a real
/// constraint rather than a validation nicety.
class Bowl {
  Bowl();

  static const double basePrice = 15.90;
  static const int baseKilojoules = 1200;
  static const int maxVegetables = 5;
  static const int maxItems = 8;

  Ingredient? base;
  Ingredient? protein;
  bool largePortion = false;
  final List<Ingredient> vegetables = [];
  Ingredient? sauce;

  /// 0 = mild, 3 = extra hot.
  int spice = 0;

  final List<Ingredient> toppings = [];

  List<Ingredient> get all => [
        if (base != null) base!,
        if (protein != null) protein!,
        ...vegetables,
        if (sauce != null) sauce!,
        ...toppings,
      ];

  int get itemCount => all.length;

  bool get isOverCapacity => itemCount > maxItems;

  double get price {
    var total = basePrice;
    for (final i in all) {
      total += i.price;
    }
    if (largePortion) total += 3.50;
    return total;
  }

  int get kilojoules {
    var total = baseKilojoules;
    for (final i in all) {
      total += i.kilojoules;
    }
    if (largePortion) total += 700;
    return total;
  }

  String get spiceLabel => const ['Mild', 'Medium', 'Hot', 'Extra hot'][spice];

  /// Shown on the cart line, for example "white-rice - ahi-tuna - miso-sesame".
  String get summary {
    final parts = [
      if (base != null) base!.id,
      if (protein != null) protein!.id,
      if (sauce != null) sauce!.id,
    ];
    return parts.isEmpty ? 'Custom bowl' : parts.join(' \u00b7 ');
  }

  int get prepMinutes => 4 + (itemCount ~/ 3);

  Bowl copy() {
    final b = Bowl()
      ..base = base
      ..protein = protein
      ..largePortion = largePortion
      ..sauce = sauce
      ..spice = spice;
    b.vegetables.addAll(vegetables);
    b.toppings.addAll(toppings);
    return b;
  }
}
