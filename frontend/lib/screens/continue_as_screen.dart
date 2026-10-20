import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'auth_screen.dart';
import 'table_number_screen.dart';

/// The fork in the road: member or guest.
///
/// The bowl is the hero and the words stay out of its way. Ingredients drift
/// around it on their own timing, so the screen is alive before anything is
/// tapped, and the choice itself is two plain rows rather than a page of
/// selling. The route taken here sets the role for the whole session, so the
/// interface and the access rules can never disagree.
class ContinueAsScreen extends StatefulWidget {
  const ContinueAsScreen({super.key});

  @override
  State<ContinueAsScreen> createState() => _ContinueAsScreenState();
}

class _ContinueAsScreenState extends State<ContinueAsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// Runs forever. Drives the drift, which is what keeps the screen from
  /// looking like a static poster.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _drift.dispose();
    super.dispose();
  }

  void _member() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
    );
  }

  void _guest() {
    AppScope.of(context).setRole(UserRole.guest);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TableNumberScreen()),
    );
  }

  Widget _stagger(double start, Widget child, {double rise = 22}) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              _stagger(0.00, const _BrandRow(), rise: 12),

              const Spacer(flex: 2),

              // The bowl is given the room. Everything else is arranged
              // around it rather than the other way round.
              Expanded(
                flex: 20,
                child: _stagger(
                  0.10,
                  _BowlStage(drift: _drift, still: reduceMotion),
                  rise: 34,
                ),
              ),

              const Spacer(flex: 2),

              _stagger(0.28, const _Headline()),
              const Spacer(flex: 3),
              _stagger(0.42, _PrimaryAction(onTap: _member)),
              const SizedBox(height: AppSpacing.md),
              _stagger(0.52, _GuestAction(onTap: _guest)),
              const SizedBox(height: AppSpacing.lg),
              _stagger(0.62, const _FinePrint(), rise: 10),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ brand

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RobomosLogo(size: 38, onDark: false),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Robomos',
                style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700, height: 1.1)),
            Text('Poke · Melbourne',
                style: AppTypography.label
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- hero

/// The bowl, with its ingredients drifting around it.
///
/// Each ingredient keeps its own phase and radius, so they never line up into
/// a pattern. The bowl itself breaks out past the top of the disc behind it,
/// which is what stops the composition reading as a flat circle with a sticker
/// in the middle.
class _BowlStage extends StatelessWidget {
  const _BowlStage({required this.drift, required this.still});

  final AnimationController drift;
  final bool still;

  // Asset name, phase, radius scale, size. These are bundled PNG images
  // (Google/Noto emoji artwork) rather than text emoji, so the orbit icons
  // render identically on every device instead of depending on the phone's
  // emoji font, which left them blank on some Android builds.
  static const _orbit = [
    ('salmon', 0.00, 0.92, 26.0),
    ('avocado', 0.18, 1.02, 22.0),
    ('greens', 0.38, 0.88, 20.0),
    ('rice', 0.55, 1.00, 24.0),
    ('chilli', 0.72, 0.94, 19.0),
    ('lemon', 0.88, 1.04, 21.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final discSize = side * 0.74;
        final radius = side * 0.44;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: AnimatedBuilder(
              animation: drift,
              builder: (context, _) {
                final t = still ? 0.25 : drift.value;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Two soft rings, the outer one fainter, so the disc has
                    // depth without needing a shadow.
                    _Ring(size: discSize * 1.3, opacity: 0.05),
                    _Ring(size: discSize * 1.08, opacity: 0.08),

                    Container(
                      width: discSize,
                      height: discSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.alphaBlend(
                                AppColors.primary.withValues(alpha: 0.22),
                                AppColors.card),
                            Color.alphaBlend(
                                AppColors.primary.withValues(alpha: 0.10),
                                AppColors.card),
                          ],
                        ),
                      ),
                    ),

                    for (final item in _orbit)
                      _Orbiter(
                        asset: item.$1,
                        phase: item.$2,
                        radiusScale: item.$3,
                        size: item.$4,
                        t: t,
                        radius: radius,
                      ),

                    // The bowl sits slightly high and a little oversized, so
                    // it crosses the edge of the disc rather than sitting
                    // inside it.
                    Transform.translate(
                      offset: Offset(
                          0, -side * 0.04 + math.sin(t * 2 * math.pi) * 5),
                      child: Text('\u{1F963}',
                          style: TextStyle(fontSize: side * 0.42)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: opacity), width: 1.4),
      ),
    );
  }
}

class _Orbiter extends StatelessWidget {
  const _Orbiter({
    required this.asset,
    required this.phase,
    required this.radiusScale,
    required this.size,
    required this.t,
    required this.radius,
  });

  final String asset;
  final double phase;
  final double radiusScale;
  final double size;
  final double t;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // A slow sweep plus a small in-and-out breath on a different period, so
    // the ingredients never settle into a ring.
    final angle = (t + phase) * 2 * math.pi;
    final breathe = 1 + math.sin((t * 3 + phase) * 2 * math.pi) * 0.05;
    final r = radius * radiusScale * breathe;

    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r * 0.86),
      child: Container(
        width: size + 18,
        height: size + 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Image.asset(
          'assets/emoji/$asset.png',
          width: size * 0.78,
          height: size * 0.78,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- headline

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your bowl,',
            style: AppTypography.screenTitle
                .copyWith(fontSize: 34, height: 1.08)),
        Text('built your way.',
            style: AppTypography.screenTitle.copyWith(
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: AppSpacing.md),
        // The short rule under the headline, lifted straight from the
        // reference: it anchors the type without adding another word.
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- actions

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Log in as a member'),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.arrow_forward, size: 18, color: AppColors.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _GuestAction extends StatelessWidget {
  const _GuestAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.base,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
        ),
        child: Text('Continue as a guest',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _FinePrint extends StatelessWidget {
  const _FinePrint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Guest orders are not saved. You can create an account later\n'
      'and keep what you have already ordered.',
      textAlign: TextAlign.center,
      style: AppTypography.label.copyWith(
          color: AppColors.textSecondary, height: 1.45),
    );
  }
}
