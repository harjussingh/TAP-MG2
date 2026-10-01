import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_typography.dart';

/// The Robomos mark, drawn in code.
///
/// Original artwork made for this project: a poke bowl that reads as a robot
/// head. Nothing is traced or imported, there is no image asset and no font
/// licence involved, so there is no attribution or copyright question. Being
/// vector it stays sharp at any size.
class RobomosLogo extends StatelessWidget {
  const RobomosLogo({
    super.key,
    this.size = 64,
    this.colour,
    this.onDark = true,
    this.badge = true,
  });

  final double size;

  /// The mark's colour. Null means the current accent, which cannot be a
  /// default value here because the palette follows the person's settings and
  /// so is no longer a compile-time constant.
  final Color? colour;

  /// Chooses the badge fill so the mark keeps contrast on either background.
  final bool onDark;

  /// Draws the rounded-square badge behind the mark.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final ink = colour ?? AppColors.primary;

    final mark = CustomPaint(
      size: Size.square(size * (badge ? 0.62 : 1)),
      painter: _RobomosPainter(colour: ink),
    );

    if (!badge) return mark;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark
            ? ink.withValues(alpha: 0.15)
            : AppColors.base.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: ink.withValues(alpha: onDark ? 0.55 : 0.35),
          width: size * 0.02,
        ),
      ),
      child: mark,
    );
  }
}

class _RobomosPainter extends CustomPainter {
  _RobomosPainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.10;

    final line = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;

    // Antenna: a stem and a ball, which is what makes the bowl read as a head.
    final stemTop = Offset(w * 0.5, h * 0.06);
    canvas.drawLine(stemTop, Offset(w * 0.5, h * 0.24), line);
    canvas.drawCircle(Offset(w * 0.5, h * 0.05), stroke * 0.75, fill);

    // The rim: a flat line across the top of the bowl.
    canvas.drawLine(
      Offset(w * 0.10, h * 0.40),
      Offset(w * 0.90, h * 0.40),
      line,
    );

    // The bowl: a half-round below the rim.
    final bowl = Path()
      ..moveTo(w * 0.17, h * 0.40)
      ..arcToPoint(
        Offset(w * 0.83, h * 0.40),
        radius: Radius.circular(w * 0.36),
        clockwise: false,
      );
    canvas.drawPath(bowl, line);

    // Two eyes inside the bowl, set wide so the face reads at small sizes.
    canvas.drawCircle(Offset(w * 0.37, h * 0.60), stroke * 0.72, fill);
    canvas.drawCircle(Offset(w * 0.63, h * 0.60), stroke * 0.72, fill);
  }

  @override
  bool shouldRepaint(covariant _RobomosPainter oldDelegate) =>
      oldDelegate.colour != colour;
}

/// The mark with the restaurant name beneath it, for entry screens.
class RobomosWordmark extends StatelessWidget {
  const RobomosWordmark({
    super.key,
    this.size = 64,
    this.onDark = true,
    this.showLocation = true,
  });

  final double size;
  final bool onDark;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RobomosLogo(size: size, onDark: onDark),
        if (showLocation) ...[
          SizedBox(height: size * 0.22),
          Text(
            'ROBOMOS POKE \u00b7 MELBOURNE',
            style: AppTypography.label.copyWith(
              color: onDark ? Colors.white38 : AppColors.textSecondary,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ],
    );
  }
}
