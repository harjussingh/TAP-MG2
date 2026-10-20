import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/intro_scene.dart';
import '../widgets/robomos_logo.dart';
import 'continue_as_screen.dart';

/// The first screen. One page, no carousel: the app has one thing to say
/// before it gets out of the way.
///
/// It replaces the QR viewfinder, which asked for a camera the app never
/// used and told a first-time diner nothing about what it does.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// The loop that keeps the illustration alive.
  late final AnimationController _ambient;

  /// The one-shot that brings the page in.
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _enter.dispose();
    super.dispose();
  }

  /// Fades and lifts [child] into place, starting at [begin] through the
  /// entry controller, so the page arrives in reading order rather than all
  /// at once.
  Widget _stagger(double begin, Widget child, {double rise = 20}) {
    final curve = CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, math.min(1, begin + 0.55), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  void _start() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ContinueAsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final still = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
          child: Column(
            children: [
              _stagger(0.00, const RobomosWordmark(size: 40, onDark: false),
                  rise: 8),

              // The arch takes whatever height is left once the words and
              // the button have taken theirs, so a long translation or a
              // large text scale shrinks the picture instead of overflowing.
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: AspectRatio(
                      aspectRatio: 1 / 1.2,
                      child: _arch(still),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _stagger(
                0.20,
                Text(
                  'Order from your table\nin seconds',
                  textAlign: TextAlign.center,
                  style: AppTypography.screenTitle
                      .copyWith(fontWeight: FontWeight.w700, height: 1.25),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _stagger(
                0.28,
                Text(
                  'Tell us your table number, build your bowl, '
                  'and watch the Fishbowl make it fresh.',
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Where the reference puts page dots. There is only one page,
              // so it is the brand rule used on the continue-as screen.
              _stagger(
                0.34,
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
                rise: 12,
              ),

              const SizedBox(height: AppSpacing.xl),
              _stagger(
                0.42,
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _start,
                    child: const Text('Get started'),
                  ),
                ),
                rise: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The picture, cut to an arch, with a second arch outlined behind it and
  /// nudged down and to the left.
  Widget _arch(bool still) {
    final radius = AppSpacing.radiusCard;

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final v = CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.05, 0.75, curve: Curves.easeOutCubic),
        ).value;
        return Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -13,
            top: 15,
            right: 13,
            bottom: -15,
            child: CustomPaint(
              painter: _ArchOutline(
                colour: AppColors.primary.withValues(alpha: 0.6),
                bottomRadius: radius,
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _ArchClipper(bottomRadius: radius),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => IntroScene(
                    t: still ? 0 : _ambient.value,
                    accent: AppColors.primary,
                    dark: settings.darkMode,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ shape

/// A rectangle whose top is a half circle, squared off at the bottom by
/// [bottomRadius] so the corner follows the UI style setting.
Path _archPath(Size s, double bottomRadius) {
  final w = s.width;
  final h = s.height;
  final r = w / 2;

  // Too short for the semicircle to fit: fall back to a rounded rectangle
  // rather than drawing an arc that doubles back on itself.
  if (h <= r + 1) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & s, Radius.circular(bottomRadius)));
  }

  // clamp() is declared on num, so its result has to be pinned back to
  // double before it reaches Radius.circular and lineTo.
  final double limit = math.min(r, h - r).toDouble();
  final double br = bottomRadius.clamp(0.0, limit).toDouble();
  final path = Path()
    ..moveTo(0, h - br)
    ..lineTo(0, r)
    ..arcToPoint(Offset(w, r),
        radius: Radius.circular(r), clockwise: true)
    ..lineTo(w, h - br);

  if (br >= 1) {
    path
      ..arcToPoint(Offset(w - br, h),
          radius: Radius.circular(br), clockwise: true)
      ..lineTo(br, h)
      ..arcToPoint(Offset(0, h - br),
          radius: Radius.circular(br), clockwise: true);
  } else {
    path
      ..lineTo(w, h)
      ..lineTo(0, h);
  }

  return path..close();
}

class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper({required this.bottomRadius});

  final double bottomRadius;

  @override
  Path getClip(Size size) => _archPath(size, bottomRadius);

  @override
  bool shouldReclip(covariant _ArchClipper old) =>
      old.bottomRadius != bottomRadius;
}

class _ArchOutline extends CustomPainter {
  _ArchOutline({required this.colour, required this.bottomRadius});

  final Color colour;
  final double bottomRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawPath(
      _archPath(size, bottomRadius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchOutline old) =>
      old.colour != colour || old.bottomRadius != bottomRadius;
}
