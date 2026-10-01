import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum DishTag {
  popular('Popular'),
  bestseller('Bestseller'),
  vegan('VG'),
  glutenFree('GF'),
  spicy('Spicy'),
  custom('Custom');

  const DishTag(this.label);
  final String label;
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.sauce,
    required this.price,
    required this.kilojoules,
    required this.emoji,
    Color? tileColour,
    this.tags = const {},
    this.inStock = true,
    this.isCustom = false,
  }) : _tileColour = tileColour;

  final String id;
  final String name;
  final String ingredients;
  final String sauce;
  final double price;
  final int kilojoules;
  final String emoji;
  final Color? _tileColour;

  /// Falls back to the cream tile, which cannot be a default parameter
  /// because the palette follows the person's theme choice.
  Color get tileColour => _tileColour ?? AppColors.tileCream;
  final Set<DishTag> tags;
  final bool inStock;

  /// Opens the bowl builder instead of adding straight to the cart.
  final bool isCustom;

  String get formattedPrice =>
      isCustom ? 'From \$${price.toStringAsFixed(2)}' : '\$${price.toStringAsFixed(2)}';
}

/// The filter chips above the menu. Keeping the rules on the enum means the
/// screen holds no matching logic and the rules can be unit tested.
enum MenuFilter {
  all('All'),
  popular('Popular'),
  vegan('Vegan'),
  glutenFree('GF'),
  custom('Custom');

  const MenuFilter(this.label);
  final String label;

  bool matches(Dish dish) {
    switch (this) {
      case MenuFilter.all:
        return true;
      case MenuFilter.popular:
        return dish.tags.contains(DishTag.popular) ||
            dish.tags.contains(DishTag.bestseller);
      case MenuFilter.vegan:
        return dish.tags.contains(DishTag.vegan);
      case MenuFilter.glutenFree:
        return dish.tags.contains(DishTag.glutenFree);
      case MenuFilter.custom:
        return dish.isCustom;
    }
  }
}
