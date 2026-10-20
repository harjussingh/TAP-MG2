import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The illustration that sits inside the arch on the intro screen.
///
/// Drawn in code rather than shipped as a photograph: there is no asset to
/// licence, it recolours with the accent and with dark mode, and it stays
/// sharp at whatever size the arch ends up.
///
/// The painter is pure. It takes its colours as parameters and never reads
/// [AppColors] itself, so it can be repainted on an animation tick without
/// touching the settings.
class IntroScene extends StatelessWidget {
  const IntroScene({
    super.key,
    required this.t,
    required this.accent,
    required this.dark,
  });

  /// Ambient clock, 0 to 1, looping.
  final double t;
  final Color accent;
  final bool dark;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        painter: _IntroPainter(t: t, accent: accent, dark: dark),
      );
}

class _IntroPainter extends CustomPainter {
  _IntroPainter({required this.t, required this.accent, required this.dark});

  final double t;
  final Color accent;
  final bool dark;

  /// Six toppings. The first five also fall from the nozzle.
  List<Color> get _toppings => dark
      ? const [
          Color(0xFFE8826B),
          Color(0xFF6FBF8B),
          Color(0xFFEBC065),
          Color(0xFF80A9D6),
          Color(0xFFD98BB0),
          Color(0xFF9AD0C0),
        ]
      : const [
          Color(0xFFE2593F),
          Color(0xFF3DAA6D),
          Color(0xFFE5A32E),
          Color(0xFF5B8FC7),
          Color(0xFFC96C97),
          Color(0xFF6FC2AC),
        ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // The counter top. Everything below it is nearer the viewer.
    final surfaceY = h * 0.58;
    final machineTop = h * 0.29;

    _backdrop(canvas, w, h);
    _lightPool(canvas, w, h);
    _surface(canvas, w, h, surfaceY);
    if (h > 140) _machine(canvas, w, h, machineTop, surfaceY);

    final bowlY = surfaceY + (h - surfaceY) * 0.44;
    final bowlRx = w * 0.30;
    final rimTop = bowlY - bowlRx * 0.30;

    _falling(canvas, w, surfaceY - h * 0.03, rimTop);
    _bowl(canvas, w, bowlY, bowlRx);
    _steam(canvas, w, h, rimTop);
  }

  // ---------------------------------------------------------------- room

  void _backdrop(Canvas c, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF2B2521), Color(0xFF17130F)]
              : const [Color(0xFFF9ECD6), Color(0xFFEBD8B6)],
        ).createShader(rect),
    );
  }

  /// A pendant lamp's pool of light, breathing slowly.
  void _lightPool(Canvas c, double w, double h) {
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final centre = Offset(w / 2, h * 0.04);
    final r = w * 0.85;
    c.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.11 + 0.07 * pulse),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
  }

  void _surface(Canvas c, double w, double h, double y) {
    final wood = dark ? const Color(0xFF2C2521) : const Color(0xFFD9BE93);
    final edge = dark ? const Color(0xFF362D27) : const Color(0xFFE6D0AB);
    c.drawRect(Rect.fromLTRB(0, y, w, h), Paint()..color = wood);
    c.drawRect(Rect.fromLTRB(0, y, w, y + 5), Paint()..color = edge);
  }

  // ------------------------------------------------------------- machine

  void _machine(Canvas c, double w, double h, double top, double bottom) {
    final cx = w / 2;
    final bodyW = w * 0.40;
    final left = cx - bodyW / 2;
    final right = cx + bodyW / 2;

    final shell = dark ? const Color(0xFF3B342C) : const Color(0xFFF4EEE4);
    final shade = dark ? const Color(0xFF2D2721) : const Color(0xFFDFD5C5);

    // Dome.
    final dome = Rect.fromCircle(center: Offset(cx, top), radius: bodyW / 2);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [shell, shade],
    ).createShader(Rect.fromLTRB(left, top - bodyW / 2, right, bottom));
    c.drawArc(dome, math.pi, math.pi, true, Paint()..shader = shader);

    // Body.
    final body = RRect.fromLTRBR(
        left, top, right, bottom, const Radius.circular(9));
    c.drawRRect(body, Paint()..shader = shader);

    final span = bottom - top;

    // The accent panel, which is where the bowl is assembled.
    final panelH = span * 0.15;
    final panelTop = top + span * 0.17;
    c.drawRRect(
      RRect.fromLTRBR(
        left + bodyW * 0.15,
        panelTop,
        right - bodyW * 0.15,
        panelTop + panelH,
        Radius.circular(panelH / 2),
      ),
      Paint()..color = accent,
    );

    // Status light.
    final blink = 0.5 + 0.5 * math.sin(t * math.pi * 6);
    c.drawCircle(
      Offset(cx, top + span * 0.52),
      bodyW * 0.045,
      Paint()..color = accent.withValues(alpha: 0.3 + 0.7 * blink),
    );

    // Nozzle, sitting just inside the bottom edge.
    final nozTop = bottom - span * 0.12;
    final noz = Path()
      ..moveTo(cx - bodyW * 0.11, nozTop)
      ..lineTo(cx + bodyW * 0.11, nozTop)
      ..lineTo(cx + bodyW * 0.055, bottom)
      ..lineTo(cx - bodyW * 0.055, bottom)
      ..close();
    c.drawPath(noz, Paint()..color = shade);
  }

  /// Toppings dropping from the nozzle into the bowl, each on its own phase.
  void _falling(Canvas c, double w, double fromY, double toY) {
    if (toY <= fromY) return;
    final cx = w / 2;
    for (var i = 0; i < 5; i++) {
      final phase = (t * 2 + i / 5) % 1.0;
      final y = fromY + (toY - fromY) * phase;
      final fade = phase < 0.18
          ? phase / 0.18
          : (phase > 0.78 ? (1 - phase) / 0.22 : 1.0);
      final drift = math.sin(i * 1.7) * w * 0.05 * phase;
      c.drawCircle(
        Offset(cx + drift, y),
        w * 0.021,
        Paint()..color = _toppings[i].withValues(alpha: fade.clamp(0.0, 1.0)),
      );
    }
  }

  // ---------------------------------------------------------------- bowl

  void _bowl(Canvas c, double w, double cy, double rx) {
    final cx = w / 2;
    final ry = rx * 0.30;
    final depth = rx * 0.54;

    final ceramic = dark ? const Color(0xFFEFE7DA) : const Color(0xFFFFFFFF);
    final ceramicShade =
        dark ? const Color(0xFFCCC0AE) : const Color(0xFFEAE1D3);

    // Contact shadow.
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + depth * 0.78),
        width: rx * 2.1,
        height: ry * 0.85,
      ),
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.34 : 0.13),
    );

    // Body: the lower half of a tall ellipse.
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: (ry + depth) * 2,
    );
    c.save();
    c.clipRect(Rect.fromLTRB(cx - rx, cy, cx + rx, cy + depth + ry));
    c.drawOval(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ceramic, ceramicShade],
        ).createShader(bodyRect),
    );
    c.restore();

    // Rim and contents.
    final rim = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    c.drawOval(
      rim,
      Paint()..color = dark ? const Color(0xFF2A241E) : const Color(0xFF3B2F27),
    );

    c.save();
    c.clipPath(Path()..addOval(rim));
    // Rice.
    c.drawOval(
      rim.deflate(1.5),
      Paint()..color = dark ? const Color(0xFFEDE4D2) : const Color(0xFFF8F2E4),
    );
    // Toppings, arranged so no two of the same colour touch.
    const spots = [
      Offset(-0.46, -0.30),
      Offset(0.44, -0.32),
      Offset(-0.50, 0.28),
      Offset(0.48, 0.30),
      Offset(0.00, 0.04),
      Offset(-0.02, -0.58),
    ];
    for (var i = 0; i < spots.length; i++) {
      final o = Offset(cx + spots[i].dx * rx, cy + spots[i].dy * ry);
      final mr = rx * 0.25;
      c.drawOval(
        Rect.fromCenter(center: o, width: mr * 2, height: mr * 1.24),
        Paint()..color = _toppings[i],
      );
    }
    c.restore();

    // Ceramic rim over the top of the contents.
    c.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, rx * 0.035)
        ..color = ceramic,
    );
  }

  /// Three curls of steam, because the bowl is made to order.
  void _steam(Canvas c, double w, double h, double topY) {
    final cx = w / 2;
    final len = h * 0.11;
    if (len <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final phase = (t * 1.4 + i / 3) % 1.0;
      final x = cx + (i - 1) * w * 0.11;
      final y0 = topY - w * 0.02 - phase * len * 0.5;
      paint.color = (dark ? Colors.white : const Color(0xFFB49A74))
          .withValues(alpha: (1 - phase) * 0.4);

      final path = Path()..moveTo(x, y0);
      for (var s = 1; s <= 8; s++) {
        final f = s / 8;
        path.lineTo(
          x + math.sin(f * math.pi * 2 + phase * 6) * w * 0.02,
          y0 - len * f,
        );
      }
      c.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroPainter old) =>
      old.t != t || old.accent != accent || old.dark != dark;
}
