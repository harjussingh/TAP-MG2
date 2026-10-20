import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';

/// The illustrated scene behind the entry screens.
///
/// Drawn entirely in code: there is no image file, no licence and nothing to
/// ship, and it stays sharp at any size. The subject is the thing the whole
/// product is about — the Fishbowl machine dropping ingredients into a bowl —
/// so the first screen shows what the restaurant actually does rather than a
/// stock photograph of a salad.
///
/// Everything animates off one looping value, so there is a single controller
/// rather than six.
class KitchenScene extends StatelessWidget {
  const KitchenScene({super.key, required this.t, this.still = false});

  /// Loops 0 to 1. Clouds drift, the sun breathes, ingredients fall.
  final double t;
  final bool still;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return CustomPaint(
      painter: _ScenePainter(
        t: still ? 0.3 : t,
        accent: AppColors.primary,
        dark: settings.darkMode,
      ),
      size: Size.infinite,
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.t, required this.accent, required this.dark});

  final double t;
  final Color accent;
  final bool dark;

  // Daylight in light mode, dusk in dark mode. The composition is identical;
  // only the palette moves, so the scene never fights the rest of the theme.
  Color get _skyTop => dark ? const Color(0xFF16222F) : const Color(0xFFAFDCF2);
  Color get _skyBottom =>
      dark ? const Color(0xFF243647) : const Color(0xFFE4F3FB);
  Color get _hillFar => dark ? const Color(0xFF24404A) : const Color(0xFFBCE3C3);
  Color get _hillNear =>
      dark ? const Color(0xFF1C3A3C) : const Color(0xFF93D3A4);
  Color get _ground => dark ? const Color(0xFF16302F) : const Color(0xFF6FC088);
  Color get _cloud => dark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.92);
  Color get _sun => dark ? const Color(0xFFE8C170) : const Color(0xFFFFD66B);
  Color get _metal => dark ? const Color(0xFF3A4450) : const Color(0xFFE9EEF3);
  Color get _metalDark =>
      dark ? const Color(0xFF2A333D) : const Color(0xFFCBD6E0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (w <= 0 || h <= 0) return;

    _sky(canvas, w, h);
    _sunAndClouds(canvas, w, h);
    _hills(canvas, w, h);
    // Below this the machine would be a few pixels tall and only add noise,
    // so the strip keeps just the sky and hills.
    if (h > 150) _machine(canvas, w, h);
  }

  void _sky(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _sunAndClouds(Canvas canvas, double w, double h) {
    // The sun breathes on a slow cycle so the light feels alive rather than
    // printed.
    final breathe = 1 + math.sin(t * 2 * math.pi) * 0.06;
    final centre = Offset(w * 0.80, h * 0.26);
    final r = h * 0.11 * breathe;

    canvas.drawCircle(
        centre, r * 1.9, Paint()..color = _sun.withValues(alpha: 0.14));
    canvas.drawCircle(
        centre, r * 1.4, Paint()..color = _sun.withValues(alpha: 0.22));
    canvas.drawCircle(centre, r, Paint()..color = _sun);

    // Three clouds at different speeds and depths. Each wraps around rather
    // than resetting, so nothing ever pops.
    _cloudAt(canvas, w, h, phase: 0.00, speed: 1.0, y: 0.20, scale: 1.00);
    _cloudAt(canvas, w, h, phase: 0.45, speed: 0.6, y: 0.36, scale: 0.72);
    _cloudAt(canvas, w, h, phase: 0.75, speed: 1.4, y: 0.13, scale: 0.55);
  }

  void _cloudAt(
    Canvas canvas,
    double w,
    double h, {
    required double phase,
    required double speed,
    required double y,
    required double scale,
  }) {
    final span = w * 1.5;
    final x = ((t * speed + phase) % 1.0) * span - w * 0.25;
    final cy = h * y;
    final unit = h * 0.075 * scale;
    final paint = Paint()..color = _cloud;

    canvas.drawCircle(Offset(x, cy), unit, paint);
    canvas.drawCircle(Offset(x + unit * 1.0, cy - unit * 0.42), unit * 0.82, paint);
    canvas.drawCircle(Offset(x + unit * 2.0, cy), unit * 0.70, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - unit * 0.6, cy - unit * 0.1, unit * 3.2, unit * 1.1),
        Radius.circular(unit),
      ),
      paint,
    );
  }

  void _hills(Canvas canvas, double w, double h) {
    // Two overlapping rounded ridges, then the ground the machine stands on.
    final far = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.22, h * 0.56, w * 0.48, h * 0.72)
      ..quadraticBezierTo(w * 0.72, h * 0.86, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = _hillFar);

    final near = Path()
      ..moveTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.30, h * 0.70, w * 0.62, h * 0.83)
      ..quadraticBezierTo(w * 0.84, h * 0.92, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = _hillNear);

    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.90, w, h * 0.10), Paint()..color = _ground);
  }

  /// The Fishbowl machine: a rounded body with a glass dome, a nozzle, and
  /// ingredients dropping into the bowl beneath it.
  void _machine(Canvas canvas, double w, double h) {
    final cx = w * 0.30;
    final baseY = h * 0.93;
    final unit = h * 0.30;

    // Body
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - unit * 0.46, baseY - unit * 0.80, unit * 0.92,
          unit * 0.80),
      topLeft: Radius.circular(unit * 0.18),
      topRight: Radius.circular(unit * 0.18),
      bottomLeft: Radius.circular(unit * 0.06),
      bottomRight: Radius.circular(unit * 0.06),
    );
    canvas.drawRRect(body, Paint()..color = _metal);
    canvas.drawRRect(
      body,
      Paint()
        ..color = _metalDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02,
    );

    // The accent panel across the front, which is where the brand colour
    // lands in the scene.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - unit * 0.34, baseY - unit * 0.70, unit * 0.68,
            unit * 0.16),
        Radius.circular(unit * 0.06),
      ),
      Paint()..color = accent,
    );

    // Two status lights, the second blinking on a different cycle.
    canvas.drawCircle(Offset(cx - unit * 0.22, baseY - unit * 0.40),
        unit * 0.035, Paint()..color = const Color(0xFF3DAA6D));
    canvas.drawCircle(
        Offset(cx - unit * 0.10, baseY - unit * 0.40),
        unit * 0.035,
        Paint()
          ..color = accent.withValues(
              alpha: 0.4 + (math.sin(t * 6 * math.pi) + 1) / 2 * 0.6));

    // Dome
    final domeRect = Rect.fromCenter(
      center: Offset(cx, baseY - unit * 0.80),
      width: unit * 0.74,
      height: unit * 0.74,
    );
    canvas.drawArc(domeRect, math.pi, math.pi, true,
        Paint()..color = Colors.white.withValues(alpha: dark ? 0.16 : 0.55));
    canvas.drawArc(
      domeRect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _metalDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02,
    );

    // Nozzle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + unit * 0.44, baseY - unit * 0.62, unit * 0.30,
            unit * 0.07),
        Radius.circular(unit * 0.035),
      ),
      Paint()..color = _metalDark,
    );

    // Ingredients falling from the nozzle into the bowl. Each has its own
    // offset in the loop so they form a stream rather than a row.
    final dropX = cx + unit * 0.70;
    final fromY = baseY - unit * 0.52;
    final toY = baseY - unit * 0.17;
    const colours = [
      Color(0xFFE8705A), // salmon
      Color(0xFF7BC47F), // avocado
      Color(0xFFF2C14E), // corn
      Color(0xFFE2593F), // chilli
    ];

    for (var i = 0; i < colours.length; i++) {
      final p = ((t * 2) + i / colours.length) % 1.0;
      // Fade in at the top and out as it lands, so nothing appears from
      // nowhere or stops dead.
      final fade = p < 0.12
          ? p / 0.12
          : p > 0.86
              ? (1 - p) / 0.14
              : 1.0;
      canvas.drawCircle(
        Offset(dropX + math.sin(p * math.pi * 2) * unit * 0.015,
            fromY + (toY - fromY) * p),
        unit * 0.045,
        Paint()..color = colours[i].withValues(alpha: fade.clamp(0.0, 1.0)),
      );
    }

    // Bowl
    final bowlRect = Rect.fromCenter(
      center: Offset(dropX, baseY - unit * 0.14),
      width: unit * 0.46,
      height: unit * 0.34,
    );
    canvas.drawArc(bowlRect, 0, math.pi, true, Paint()..color = _metal);
    canvas.drawArc(
      bowlRect,
      0,
      math.pi,
      false,
      Paint()
        ..color = _metalDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dropX - unit * 0.27, baseY - unit * 0.17, unit * 0.54,
            unit * 0.05),
        Radius.circular(unit * 0.025),
      ),
      Paint()..color = _metalDark,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.accent != accent || old.dark != dark;
}
