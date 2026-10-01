import '../models/dish.dart';
import '../models/ingredient.dart';
import '../theme/app_colors.dart';

/// Stand-in for the API. Replace these lists with calls to the backend once
/// the endpoints exist; the shape below is the agreed contract.
List<Dish> kDishes = [
  Dish(
    id: 'robo-classic',
    name: 'Robo Classic',
    ingredients: 'Salmon, avocado, cucumber',
    sauce: 'Sriracha mayo',
    price: 18.90,
    kilojoules: 2180,
    emoji: '\u{1F41F}',
    tileColour: AppColors.tilePink,
    tags: {DishTag.popular, DishTag.spicy},
  ),
  Dish(
    id: 'garden-zen',
    name: 'Garden Zen',
    ingredients: 'Edamame, tofu, pickled ginger',
    sauce: 'Miso sesame',
    price: 16.90,
    kilojoules: 1630,
    emoji: '\u{1F966}',
    tileColour: AppColors.tileGreen,
    tags: {DishTag.vegan, DishTag.glutenFree},
  ),
  Dish(
    id: 'tuna-poke',
    name: 'Tuna Poke',
    ingredients: 'Ahi tuna, mango, spring onion',
    sauce: 'Ponzu',
    price: 19.90,
    kilojoules: 2010,
    emoji: '\u{1F34B}',
    tags: {DishTag.popular},
  ),
  Dish(
    id: 'chicken-teriyaki',
    name: 'Chicken Teriyaki',
    ingredients: 'Teriyaki chicken, edamame, corn',
    sauce: 'Sweet soy',
    price: 17.90,
    kilojoules: 2340,
    emoji: '\u{1F357}',
    tags: {DishTag.bestseller},
  ),
  Dish(
    id: 'spicy-salmon',
    name: 'Spicy Salmon',
    ingredients: 'Salmon, jalape\u00f1o, red onion',
    sauce: 'Chilli sesame',
    price: 19.50,
    kilojoules: 2260,
    emoji: '\u{1F336}',
    tileColour: AppColors.tilePink,
    tags: {DishTag.glutenFree},
    inStock: false,
  ),
  Dish(
    id: 'build-your-own',
    name: 'Build Your Own Bowl',
    ingredients: 'Choose your base, protein and toppings',
    sauce: '',
    price: 15.90,
    kilojoules: 0,
    emoji: '\u{1F963}',
    tileColour: AppColors.tileBlue,
    tags: {DishTag.custom},
    isCustom: true,
  ),
];

const List<Ingredient> kBases = [
  Ingredient(id: 'white-rice', name: 'White Rice', emoji: '\u{1F35A}', kind: IngredientKind.base, kilojoules: 0),
  Ingredient(id: 'brown-rice', name: 'Brown Rice', emoji: '\u{1F33E}', kind: IngredientKind.base, kilojoules: 60),
  Ingredient(id: 'noodles', name: 'Noodles', emoji: '\u{1F35C}', kind: IngredientKind.base, price: 0.50, kilojoules: 180),
  Ingredient(id: 'greens', name: 'Greens', emoji: '\u{1F96C}', kind: IngredientKind.base, kilojoules: -300),
];

const List<Ingredient> kProteins = [
  Ingredient(id: 'ahi-tuna', name: 'Ahi Tuna', emoji: '\u{1F41F}', kind: IngredientKind.protein, price: 3.00, kilojoules: 420),
  Ingredient(id: 'salmon', name: 'Salmon', emoji: '\u{1F363}', kind: IngredientKind.protein, price: 3.00, kilojoules: 480),
  Ingredient(id: 'chicken', name: 'Teriyaki Chicken', emoji: '\u{1F357}', kind: IngredientKind.protein, price: 2.50, kilojoules: 520),
  Ingredient(id: 'tofu', name: 'Tofu', emoji: '\u{1F9C6}', kind: IngredientKind.protein, price: 2.00, kilojoules: 300),
  Ingredient(id: 'prawn', name: 'Prawn', emoji: '\u{1F364}', kind: IngredientKind.protein, price: 3.50, kilojoules: 360, inStock: false),
];

const List<Ingredient> kVegetables = [
  Ingredient(id: 'cucumber', name: 'Cucumber', emoji: '\u{1F952}', kind: IngredientKind.vegetable, kilojoules: 30),
  Ingredient(id: 'avocado', name: 'Avocado', emoji: '\u{1F951}', kind: IngredientKind.vegetable, price: 1.50, kilojoules: 340),
  Ingredient(id: 'mango', name: 'Mango', emoji: '\u{1F96D}', kind: IngredientKind.vegetable, price: 1.00, kilojoules: 250),
  Ingredient(id: 'edamame', name: 'Edamame', emoji: '\u{1FAD8}', kind: IngredientKind.vegetable, price: 1.00, kilojoules: 210),
  Ingredient(id: 'corn', name: 'Sweet Corn', emoji: '\u{1F33D}', kind: IngredientKind.vegetable, kilojoules: 260),
  Ingredient(id: 'red-onion', name: 'Red Onion', emoji: '\u{1F9C5}', kind: IngredientKind.vegetable, kilojoules: 40),
  Ingredient(id: 'seaweed', name: 'Seaweed', emoji: '\u{1F343}', kind: IngredientKind.vegetable, price: 1.00, kilojoules: 60, inStock: false),
];

const List<Ingredient> kSauces = [
  Ingredient(id: 'miso-sesame', name: 'Miso Sesame', emoji: '\u{1F36F}', kind: IngredientKind.sauce, kilojoules: 190),
  Ingredient(id: 'sriracha-mayo', name: 'Sriracha Mayo', emoji: '\u{1F336}', kind: IngredientKind.sauce, kilojoules: 320),
  Ingredient(id: 'ponzu', name: 'Ponzu', emoji: '\u{1F34B}', kind: IngredientKind.sauce, kilojoules: 90),
  Ingredient(id: 'sweet-soy', name: 'Sweet Soy', emoji: '\u{1F376}', kind: IngredientKind.sauce, kilojoules: 150),
];

const List<Ingredient> kToppings = [
  Ingredient(id: 'sesame', name: 'Sesame Seeds', emoji: '\u{1F330}', kind: IngredientKind.topping, price: 0.50, kilojoules: 120),
  Ingredient(id: 'crispy-onion', name: 'Crispy Onion', emoji: '\u{1F9C5}', kind: IngredientKind.topping, price: 1.00, kilojoules: 260),
  Ingredient(id: 'nori', name: 'Nori Strips', emoji: '\u{1F363}', kind: IngredientKind.topping, price: 1.00, kilojoules: 70),
  Ingredient(id: 'chilli-flakes', name: 'Chilli Flakes', emoji: '\u{1F525}', kind: IngredientKind.topping, price: 0.50, kilojoules: 20),
];
