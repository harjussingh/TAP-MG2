import 'package:flutter/material.dart';

import 'app_settings.dart';

/// The colour a dish card is painted in.
///
/// The reference designs give every card in the carousel its own rich colour
/// rather than one brand colour repeated, which is what stops a row of food
/// cards reading as a spreadsheet. Each entry carries the text colour that
/// passes contrast on it, so no screen has to decide that for itself.
enum DishPalette {
  teal('teal', Color(0xFF1C8C7E), Color(0xFF12554C)),
  ember('ember', Color(0xFFE2593F), Color(0xFF8E2F1D)),
  crimson('crimson', Color(0xFFD03A4A), Color(0xFF86202C)),
  amber('amber', Color(0xFFE8A318), Color(0xFF8A5F06)),
  indigo('indigo', Color(0xFF4256C4), Color(0xFF25317A)),
  moss('moss', Color(0xFF5B8C2A), Color(0xFF365418));

  const DishPalette(this.key, this._light, this._dark);

  final String key;
  final Color _light;
  final Color _dark;

  /// Deepened in dark mode so a saturated card does not glare against the
  /// darker surface behind it.
  Color get colour => settings.darkMode ? _dark : _light;

  /// White everywhere: every colour above is dark enough to carry it.
  Color get onColour => Colors.white;

  /// A faint wash of the same hue, for the area the food image sits on.
  Color get wash => settings.darkMode
      ? Color.alphaBlend(_dark.withValues(alpha: 0.28), const Color(0xFF17150F))
      : Color.alphaBlend(_light.withValues(alpha: 0.14), const Color(0xFFFFFFFF));

  static DishPalette fromKey(String? key) =>
      values.firstWhere((p) => p.key == key, orElse: () => DishPalette.teal);

  /// Spreads the palette across a list so neighbouring cards never match.
  static DishPalette forIndex(int index) => values[index % values.length];
}
