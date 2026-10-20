import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';

/// The dining room, drawn in code.
///
/// The table card in the middle of the scene shows the number as it is typed,
/// so the customer is looking at the thing they are about to confirm standing
/// on a table rather than at a field with a value in it. Everything is painted
/// — no image file, no licence, sharp at any size.
class DiningRoomScene extends StatelessWidget {
  const DiningRoomScene({
    super.key,
    required this.value,
    required this.t,
    required this.landed,
    this.still = false,
  });

  /// What has been typed. Empty shows a blank card.
  final String value;

  /// Loops 0 to 1: the lamp sways and the light shifts off this.
  final double t;

  /// 0 to 1 once per digit, which makes the card react.
  final double landed;

  final bool still;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return CustomPaint(
      painter: _RoomPainter(
        value: value,
        t: still ? 0.3 : t,
        landed: still ? 1 : landed,
        accent: AppColors.primary,
        // The card's corner follows the chosen UI style, so a Crisp setting
        // does not leave a rounded card sitting above square keys.
        cornerRatio: switch (settings.uiStyle) {
          UiStyle.rounded => 0.13,
          UiStyle.soft => 0.07,
          UiStyle.crisp => 0.02,
        },
        dark: settings.darkMode,
      ),
      size: Size.infinite,
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({
    required this.value,
    required this.t,
    required this.landed,
    required this.accent,
    required this.cornerRatio,
    required this.dark,
  });

  final String value;
  final double t;
  final double landed;
  final Color accent;
  final double cornerRatio;
  final bool dark;

  // Warm daylight, or a low evening room in dark mode. Same composition
  // either way; only the palette moves.
  Color get _wallTop => dark ? const Color(0xFF241F1A) : const Color(0xFFF6E7D2);
  Color get _wallBottom =>
      dark ? const Color(0xFF1A1613) : const Color(0xFFEFD9BE);
  Color get _window => dark ? const Color(0xFF2B3A4A) : const Color(0xFFCFE8F5);
  Color get _frame => dark ? const Color(0xFF3B332B) : const Color(0xFFD8BE9B);
  Color get _floor => dark ? const Color(0xFF16120F) : const Color(0xFFE2C9A6);
  Color get _tableTop =>
      dark ? const Color(0xFF3A2E24) : const Color(0xFFC98F52);
  Color get _tableEdge =>
      dark ? const Color(0xFF261D16) : const Color(0xFFA8703A);
  Color get _chair => dark ? const Color(0xFF2E2620) : const Color(0xFF8C5E31);
  Color get _card => dark ? const Color(0xFFE8E2D8) : const Color(0xFFFFFDF8);
  Color get _cardInk =>
      dark ? const Color(0xFF1B1713) : const Color(0xFF221C16);
  Color get _plant => dark ? const Color(0xFF2B4034) : const Color(0xFF5D9A63);

  /// Lamplight is warm, not accent-coloured. In dark mode the lamp is the
  /// room's light source and has to read as switched on; in daylight the
  /// window does that job and the lamp is only a tint.
  static const Color _lampLight = Color(0xFFFFD9A0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    _wall(canvas, w, h);
    _windowAndLight(canvas, w, h);
    _machine(canvas, w, h);
    _plantPot(canvas, w, h);
    _lamp(canvas, w, h);
    _floorBand(canvas, w, h);
    _tableAndCard(canvas, w, h);
    // Last, so the light lands on the table and the card rather than under
    // them. A lamp you can see the glow of but not what it lights still
    // reads as switched off.
    _lampPool(canvas, w, h);
  }

  void _wall(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_wallTop, _wallBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  /// A window on the left with a shaft of light falling across the room. The
  /// shaft drifts, which is most of what makes the room feel occupied.
  void _windowAndLight(Canvas canvas, double w, double h) {
    final x = w * 0.08;
    final y = h * 0.12;
    final ww = w * 0.24;
    final wh = h * 0.42;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4, y - 4, ww + 8, wh + 8), const Radius.circular(10)),
      Paint()..color = _frame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, ww, wh), const Radius.circular(7)),
      Paint()..color = _window,
    );
    // Glazing bars
    final bar = Paint()
      ..color = _frame
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(x + ww / 2, y), Offset(x + ww / 2, y + wh), bar);
    canvas.drawLine(
        Offset(x, y + wh * 0.45), Offset(x + ww, y + wh * 0.45), bar);

    // The shaft, drifting on a slow cycle.
    final drift = math.sin(t * 2 * math.pi) * w * 0.03;
    final shaft = Path()
      ..moveTo(x + ww * 0.1, y + wh)
      ..lineTo(x + ww * 1.0, y + wh)
      ..lineTo(x + ww * 2.3 + drift, h)
      ..lineTo(x + ww * 0.5 + drift, h)
      ..close();
    canvas.drawPath(
      shaft,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.05 : 0.34),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x, y, w, h)),
    );
  }

  /// The Fishbowl machine, small, in the back corner.
  void _machine(Canvas canvas, double w, double h) {
    final cx = w * 0.82;
    final base = h * 0.62;
    final u = h * 0.30;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - u * 0.30, base - u * 0.62, u * 0.60, u * 0.62),
        Radius.circular(u * 0.10),
      ),
      Paint()..color = dark ? const Color(0xFF39434E) : const Color(0xFFE6ECF2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - u * 0.22, base - u * 0.54, u * 0.44, u * 0.12),
        Radius.circular(u * 0.05),
      ),
      Paint()..color = accent,
    );
    // Dome
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, base - u * 0.62), width: u * 0.48, height: u * 0.48),
      math.pi,
      math.pi,
      true,
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.14 : 0.6),
    );
    // A light blinking on a different cycle, so the room has a pulse.
    canvas.drawCircle(
      Offset(cx + u * 0.16, base - u * 0.30),
      u * 0.028,
      Paint()
        ..color = accent.withValues(
            alpha: 0.35 + (math.sin(t * 8 * math.pi) + 1) / 2 * 0.65),
    );
  }

  void _plantPot(Canvas canvas, double w, double h) {
    final cx = w * 0.955;
    final base = h * 0.70;
    final u = h * 0.16;

    // Fronds, swaying very slightly out of phase with the lamp.
    final sway = math.sin(t * 2 * math.pi + 1.1) * 0.06;
    for (var i = -2; i <= 2; i++) {
      final a = -math.pi / 2 + i * 0.34 + sway;
      final p = Path()
        ..moveTo(cx, base)
        ..quadraticBezierTo(
          cx + math.cos(a) * u * 0.5,
          base + math.sin(a) * u * 0.7,
          cx + math.cos(a) * u * 1.0,
          base + math.sin(a) * u * 1.25,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = _plant
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.17
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - u * 0.32, base - u * 0.04, u * 0.64, u * 0.42),
        bottomLeft: Radius.circular(u * 0.12),
        bottomRight: Radius.circular(u * 0.12),
      ),
      Paint()..color = dark ? const Color(0xFF4A3A2C) : const Color(0xFFC97B4A),
    );
  }

  /// A pendant lamp over the table, swaying.
  void _lamp(Canvas canvas, double w, double h) {
    final anchorX = w * 0.5;
    final swing = math.sin(t * 2 * math.pi) * w * 0.012;
    final shadeX = anchorX + swing;
    final shadeY = h * 0.26;
    final u = h * 0.11;

    canvas.drawLine(
      Offset(anchorX, 0),
      Offset(shadeX, shadeY - u * 0.3),
      Paint()
        ..color = _frame
        ..strokeWidth = 2,
    );

    final rimY = shadeY + u * 0.3; // the open bottom of the shade
    final rimHalf = u * 0.52;
    final bulb = Offset(shadeX, rimY + u * 0.06);

    // The halo around the bulb. Strong in a dark room, barely there in
    // daylight.
    _glow(canvas, bulb, u * 1.9, dark ? 0.40 : 0.15);

    // The cone of light falling toward the table. Drawn before the shade so
    // the shade sits on top of it, and faded out by the time it reaches the
    // floor line.
    final spread = u * 1.5;
    final reach = h * 0.40;
    final coneRect =
        Rect.fromLTRB(shadeX - spread, rimY, shadeX + spread, rimY + reach);
    canvas.drawPath(
      Path()
        ..moveTo(shadeX - rimHalf, rimY)
        ..lineTo(shadeX + rimHalf, rimY)
        ..lineTo(shadeX + spread, rimY + reach)
        ..lineTo(shadeX - spread, rimY + reach)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lampLight.withValues(alpha: dark ? 0.30 : 0.13),
            _lampLight.withValues(alpha: 0),
          ],
        ).createShader(coneRect),
    );

    // The shade itself.
    canvas.drawPath(
      Path()
        ..moveTo(shadeX - rimHalf, rimY)
        ..lineTo(shadeX - u * 0.16, shadeY - u * 0.3)
        ..lineTo(shadeX + u * 0.16, shadeY - u * 0.3)
        ..lineTo(shadeX + rimHalf, rimY)
        ..close(),
      Paint()..color = accent,
    );

    // Its lit underside, then the bulb. These two are what actually say the
    // lamp is on rather than merely present.
    canvas.drawLine(
      Offset(shadeX - rimHalf, rimY),
      Offset(shadeX + rimHalf, rimY),
      Paint()
        ..color = _lampLight.withValues(alpha: dark ? 0.95 : 0.55)
        ..strokeWidth = math.max(2, u * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      bulb,
      u * 0.13,
      Paint()..color = _lampLight.withValues(alpha: dark ? 1.0 : 0.7),
    );
  }

  /// A soft radial fade of lamplight.
  void _glow(Canvas canvas, Offset centre, double r, double alpha) {
    if (r <= 0 || alpha <= 0) return;
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _lampLight.withValues(alpha: alpha),
            _lampLight.withValues(alpha: alpha * 0.35),
            _lampLight.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
  }

  /// Where the lamplight lands on the table, swaying a little further than
  /// the lamp does because the pool is further from the pivot.
  void _lampPool(Canvas canvas, double w, double h) {
    final swing = math.sin(t * 2 * math.pi) * w * 0.012;
    final rect = Rect.fromCenter(
      center: Offset(w * 0.5 + swing * 1.8, h * 0.84),
      width: w * 0.80,
      height: h * 0.26,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _lampLight.withValues(alpha: dark ? 0.20 : 0.09),
            _lampLight.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _floorBand(Canvas canvas, double w, double h) {
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.70, w, h * 0.30), Paint()..color = _floor);
    canvas.drawLine(
      Offset(0, h * 0.70),
      Offset(w, h * 0.70),
      Paint()
        ..color = _tableEdge.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
  }

  /// The table, two chairs, and the card standing on it with the number.
  void _tableAndCard(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final topY = h * 0.84;
    final tw = w * 0.46;

    // Chair backs behind the table
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * tw * 0.58, topY - h * 0.10),
            width: w * 0.10,
            height: h * 0.16,
          ),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = _chair,
      );
    }

    // Table top, seen at a slight angle
    final top = Rect.fromCenter(
        center: Offset(cx, topY), width: tw, height: h * 0.15);
    canvas.drawOval(
        top.translate(0, h * 0.012), Paint()..color = _tableEdge);
    canvas.drawOval(top, Paint()..color = _tableTop);

    // The card, popping a little as each digit lands.
    final pop = 1 + (1 - Curves.easeOutBack.transform(landed.clamp(0, 1))) * 0.14;
    final cardW = w * 0.30 * pop;
    final cardH = h * 0.30 * pop;
    final cardRect = Rect.fromCenter(
      center: Offset(cx, topY - cardH * 0.46),
      width: cardW,
      height: cardH,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          cardRect.translate(0, 3), Radius.circular(cardW * cornerRatio)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, Radius.circular(cardW * cornerRatio)),
      Paint()..color = _card,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, Radius.circular(cardW * cornerRatio)),
      Paint()
        ..color = value.isEmpty ? _tableEdge.withValues(alpha: 0.4) : accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = value.isEmpty ? 1.5 : 2.5,
    );

    _label(canvas, 'TABLE', Offset(cx, cardRect.top + cardH * 0.22),
        cardW * 0.11, _cardInk.withValues(alpha: 0.5), 2.2, FontWeight.w700);

    _label(
      canvas,
      value.isEmpty ? '––' : value,
      Offset(cx, cardRect.top + cardH * 0.58),
      cardW * 0.42,
      value.isEmpty ? _cardInk.withValues(alpha: 0.22) : _cardInk,
      1.0,
      FontWeight.w700,
    );
  }

  void _label(Canvas canvas, String text, Offset centre, double size,
      Color colour, double spacing, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colour,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.t != t ||
      old.value != value ||
      old.landed != landed ||
      old.accent != accent ||
      old.cornerRatio != cornerRatio ||
      old.dark != dark;
}
