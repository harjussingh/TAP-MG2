import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_settings.dart';

/// Six text styles for the whole app.
///
/// Every size is multiplied by the chosen text scale, so changing it in
/// settings moves the whole type ramp together rather than one screen at a
/// time. Colours come from [AppColors], so dark mode follows too.
class AppTypography {
  const AppTypography._();

  /// Colour-emoji fallback families, applied app-wide through [AppTheme].
  ///
  /// Text is drawn in Inter (via google_fonts), which has no emoji glyphs.
  /// On the emulator the engine quietly falls back to the system emoji font,
  /// but some Android OEM builds don't, so emoji render as blank circles.
  /// Naming the system colour-emoji font here forces the fallback on every
  /// device. The names cover Android, iOS and the desktop hosts; unknown
  /// names are simply skipped.
  static const List<String> emojiFallback = <String>[
    'Noto Color Emoji',
    'NotoColorEmoji',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Emoji',
  ];

  static double _s(double size) => size * settings.textScale.factor;

  static TextStyle get screenTitle => GoogleFonts.inter(
      fontSize: _s(28),
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppColors.base);

  static TextStyle get sectionHeading => GoogleFonts.inter(
      fontSize: _s(22),
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.base);

  static TextStyle get cardTitle => GoogleFonts.inter(
      fontSize: _s(18),
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.base);

  static TextStyle get body => GoogleFonts.inter(
      fontSize: _s(16),
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.base);

  static TextStyle get secondary => GoogleFonts.inter(
      fontSize: _s(14),
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textSecondary);

  static TextStyle get label => GoogleFonts.inter(
      fontSize: _s(13),
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: AppColors.base);

  static TextTheme get textTheme => TextTheme(
        headlineLarge: screenTitle,
        headlineMedium: sectionHeading,
        titleLarge: cardTitle,
        titleMedium: cardTitle,
        bodyLarge: body,
        bodyMedium: secondary,
        labelLarge: label,
        labelMedium: label,
      );
}
