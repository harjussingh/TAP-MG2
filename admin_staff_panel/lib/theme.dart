import 'package:flutter/material.dart';

/// Palette carried over from the original HTML panel.
class RK {
  static const bg = Color(0xFF0E1216);
  static const surface = Color(0xFF161C22);
  static const surface2 = Color(0xFF1C242B);
  static const rail = Color(0xFF11161B);
  static const line = Color(0xFF28313A);
  static const lineSoft = Color(0xFF1F272E);
  static const text = Color(0xFFE9EEF3);
  static const muted = Color(0xFF90A0AE);
  static const dim = Color(0xFF64727E);
  static const queued = Color(0xFF7FA6C9);
  static const cooking = Color(0xFFF2A33C);
  static const ready = Color(0xFF39C07A);
  static const alert = Color(0xFFE2574C);
  static const awaiting = Color(0xFFB48EAD);

  static Color forStatus(String? s) => switch (s) {
        'pending_payment' => awaiting,
        'confirmed' => queued,
        'preparing' => cooking,
        'ready' => ready,
        'cancelled' => alert,
        _ => dim,
      };
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RK.bg,
    colorScheme: const ColorScheme.dark(
      primary: RK.cooking,
      onPrimary: Color(0xFF1A1206),
      secondary: RK.queued,
      surface: RK.surface,
      onSurface: RK.text,
      error: RK.alert,
      outline: RK.line,
    ),
    dividerColor: RK.line,
  );
  const radius = BorderRadius.all(Radius.circular(4));
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: RK.text, displayColor: RK.text),
    cardTheme: const CardThemeData(
      color: RK.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: RK.line)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: RK.surface2,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: TextStyle(color: RK.muted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: RK.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: RK.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: RK.cooking, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RK.cooking,
        foregroundColor: const Color(0xFF1A1206),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RK.text,
        side: const BorderSide(color: RK.line),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: RK.surface2,
        contentTextStyle: TextStyle(color: RK.text)),
    dialogTheme: const DialogThemeData(backgroundColor: RK.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: RK.line))),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RK.bg : RK.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RK.ready : RK.surface2),
    ),
  );
}
