import 'package:flutter/material.dart';

import 'app_settings.dart';

/// Colour tokens.
///
/// These are getters rather than constants because the palette now follows
/// the person's choices: dark mode swaps the neutrals, and the accent is one
/// of five. The whole app rebuilds when settings change, so every screen
/// picks up the new values.
///
/// The contrast rule still holds and is now enforced by the palette itself:
/// [onPrimary] comes from the chosen accent, so text on the accent is dark on
/// saffron and white on the darker colours, never the wrong way round.
class AppColors {
  const AppColors._();

  static bool get _dark => settings.darkMode;

  /// The accent. Changes with the theme colour the person picked.
  static Color get primary => settings.accent.colour;

  /// The only correct foreground on [primary].
  static Color get onPrimary => settings.accent.onColour;

  /// Primary ink. Flips in dark mode, so text follows automatically.
  static Color get base => _dark ? const Color(0xFFF5F2ED) : const Color(0xFF141210);

  /// The dark band behind entry screens and app bars. Stays dark in both
  /// modes, which is why it is separate from [base].
  static Color get header => _dark ? const Color(0xFF0B0A09) : const Color(0xFF141210);

  /// Always white, for text drawn on [header].
  static const Color onHeader = Color(0xFFFFFFFF);

  static Color get surface => _dark ? const Color(0xFF121110) : const Color(0xFFFAF7F2);

  static Color get card => _dark ? const Color(0xFF1E1B19) : const Color(0xFFFFFFFF);

  static Color get border => _dark ? const Color(0xFF302C28) : const Color(0xFFE7E2DA);

  static Color get textSecondary =>
      _dark ? const Color(0xFFA9A29A) : const Color(0xFF57534E);

  static Color get disabled => _dark ? const Color(0xFF3A3531) : const Color(0xFFD6D0C7);

  static const Color success = Color(0xFF3DAA6D);
  static const Color error = Color(0xFFE2593F);

  /// Tinted backgrounds behind dish tiles. Muted in dark mode so they do not
  /// glare against the darker surface.
  static Color get tilePink =>
      _dark ? const Color(0xFF3A2529) : const Color(0xFFFDECEF);
  static Color get tileGreen =>
      _dark ? const Color(0xFF1F3325) : const Color(0xFFE9F3EA);
  static Color get tileCream =>
      _dark ? const Color(0xFF3A3020) : const Color(0xFFFDF3E3);
  static Color get tileBlue =>
      _dark ? const Color(0xFF22293D) : const Color(0xFFEAEEFB);
}
