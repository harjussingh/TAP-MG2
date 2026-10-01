import 'app_settings.dart';

/// The spacing scale. If a value is not on it, round to the nearest one.
///
/// Spacing itself is fixed; only the corner radii follow the UI style the
/// person picked, which is why those three are getters.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double screenPadding = lg;
  static const double cardPadding = lg;
  static const double cardGap = md;
  static const double sectionGap = xl;

  /// Android minimum tappable area, applied even when the visible element is
  /// smaller.
  static const double minTouchTarget = 48;

  static const double buttonHeight = 56;
  static const double inputHeight = 56;
  static const double thumbnailSize = 88;
  static const double chipHeight = 40;

  // Rounded, Soft or Crisp.
  static double get radiusCard => settings.uiStyle.card;
  static double get radiusInput => settings.uiStyle.input;
  static double get radiusPill => settings.uiStyle.pill;
}
