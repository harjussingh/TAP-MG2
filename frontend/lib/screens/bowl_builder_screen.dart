import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/sample_data.dart';
import '../models/bowl.dart';
import '../models/ingredient.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/name_prompt.dart';
import 'cart_screen.dart';

/// The six-step builder.
///
/// This is the core of the product: what the customer assembles here is the
/// instruction the machine receives, which is why the last step shows the whole
/// bowl back to them and nothing is sent until they confirm it.
///
/// Each step is a list of full-width rows rather than a grid, so the name, the
/// extra charge and the energy fit on one line and the running total never
/// leaves the screen.

class BowlBuilderScreen extends StatefulWidget {
  const BowlBuilderScreen({super.key, this.startFrom});

  /// A saved recipe to reopen. The builder works on a copy, so editing a
  /// reopened bowl does not quietly rewrite the one in the saved list.
  final Bowl? startFrom;

  @override
  State<BowlBuilderScreen> createState() => _BowlBuilderScreenState();
}

class _BowlBuilderScreenState extends State<BowlBuilderScreen> {
  late final Bowl _bowl;
  late int _step;

  /// True when this was opened from the saved list, which changes what the
  /// last step offers: saving again should add a variation, not a duplicate.
  bool get _reopened => widget.startFrom != null;

  @override
  void initState() {
    super.initState();
    // widget is available here; inherited widgets are not, which is why
    // nothing in this method reads AppScope.
    _bowl = widget.startFrom?.copy() ?? Bowl();
    // A saved recipe is already complete, so it opens on the review step
    // with every section one tap away rather than walking all six again.
    _step = _reopened ? 6 : 1;
  }

  static const _titles = [
    'Choose your base',
    'Pick your protein',
    'Add vegetables',
    'Sauce and spice',
    'Finish with toppings',
    'Check it over',
  ];

  static const _subtitles = [
    'It goes down first.',
    'The machine portions this by weight.',
    'Up to five. Pick what you like.',
    'One sauce, then set the heat.',
    'Optional, but this is where it gets good.',
    'Tap any section to change it before sending.',
  ];

  bool get _canAdvance {
    switch (_step) {
      case 1:
        return _bowl.base != null;
      case 2:
        return _bowl.protein != null;
      case 4:
        return _bowl.sauce != null;
      default:
        return true;
    }
  }

  void _next() => setState(() => _step = min(6, _step + 1));

  /// Skip is offered on the two steps a bowl can do without — vegetables and
  /// toppings — and only while nothing has been chosen on them. Once there
  /// is a selection, Skip would mean "discard that", which is not what the
  /// word says, so it goes away and Next is the only way on.
  ///
  /// It is deliberately absent from the required steps: a bowl with no base,
  /// no protein or no sauce is not something the machine can build, and a
  /// Skip on every screen teaches people the word means nothing.
  VoidCallback? get _onSkip {
    final skippable = (_step == 3 && _bowl.vegetables.isEmpty) ||
        (_step == 5 && _bowl.toppings.isEmpty);
    return skippable ? _next : null;
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _surpriseMe() {
    final rng = Random();
    setState(() {
      _bowl.base = kBases[rng.nextInt(kBases.length)];
      final proteins = kProteins.where((i) => i.inStock).toList();
      _bowl.protein = proteins[rng.nextInt(proteins.length)];
      _bowl.vegetables
        ..clear()
        ..addAll((kVegetables.where((i) => i.inStock).toList()..shuffle(rng))
            .take(2));
      _bowl.sauce = kSauces[rng.nextInt(kSauces.length)];
      _bowl.spice = rng.nextInt(4);
      _bowl.toppings.clear();
      _step = 6;
    });
  }

  void _sendToMachine() {
    final state = AppScope.of(context);
    state.addToCart(CartLine(
      title: 'Build Your Own Bowl',
      subtitle: _bowl.summary,
      emoji: '\u{1F963}',
      price: _bowl.price,
      kilojoules: _bowl.kilojoules,
      isCustom: true,
    ));

    showAddedToCart(
      context,
      title: 'Your custom bowl',
      subtitle: _bowl.summary,
      emoji: '\u{1F963}',
      onViewCart: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CartScreen()),
        );
      },
    );
  }

  String _energyLabel(Ingredient i) =>
      i.kilojoules == 0 ? 'Included' : '${i.kilojoules > 0 ? '+' : ''}${i.kilojoules} kJ';

  String? _priceLabel(Ingredient i) =>
      i.price > 0 ? '+ ${formatPrice(i.price)}' : null;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Header(
            step: _step,
            title: _titles[_step - 1],
            subtitle: _subtitles[_step - 1],
            bowl: _bowl,
            onClose: () => Navigator.pop(context),
            onSurprise: _surpriseMe,
          ),
          if (_bowl.isOverCapacity) const _CapacityWarning(),
          // Expanded: the content takes all the space between the header and
          // the footer, so the footer is pinned to the same spot above the
          // bottom edge on every step — identical height and position whether
          // the step is short or long. The list scrolls when it is long.
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.06, 0), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
            ),
          ),
          // Footer directly under the content — compact, always present.
          _BottomBar(
            bowl: _bowl,
            isLast: _step == 6,
            canAdvance: _canAdvance && !_bowl.isOverCapacity,
            onNext: _step == 6 ? _sendToMachine : _next,
            onBack: _back,
            onSkip: _onSkip,
          ),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 1:
        return _list([
          _grid(
            kBases,
            isSelected: (o) => _bowl.base?.id == o.id,
            onTap: (o) => setState(() => _bowl.base = o),
          ),
        ]);

      case 2:
        return _list([
          _grid(
            kProteins,
            isSelected: (o) => _bowl.protein?.id == o.id,
            onTap: (o) => setState(() => _bowl.protein = o),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PortionToggle(
            large: _bowl.largePortion,
            onChanged: (v) => setState(() => _bowl.largePortion = v),
          ),
        ]);

      case 3:
        return _list([
          _Counter(
            label: '${_bowl.vegetables.length} of ${Bowl.maxVegetables} chosen',
          ),
          _grid(
            kVegetables,
            isSelected: (o) => _bowl.vegetables.contains(o),
            // A vegetable already chosen stays tappable so it can be taken
            // back off once the limit is reached.
            available: (o) =>
                o.inStock &&
                (_bowl.vegetables.contains(o) ||
                    _bowl.vegetables.length < Bowl.maxVegetables),
            onTap: (o) => setState(() {
              if (!_bowl.vegetables.remove(o) &&
                  _bowl.vegetables.length < Bowl.maxVegetables) {
                _bowl.vegetables.add(o);
              }
            }),
          ),
        ]);

      case 4:
        return _list([
          _grid(
            kSauces,
            isSelected: (o) => _bowl.sauce?.id == o.id,
            onTap: (o) => setState(() => _bowl.sauce = o),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SpiceCard(
            spice: _bowl.spice,
            label: _bowl.spiceLabel,
            onChanged: (v) => setState(() => _bowl.spice = v),
          ),
        ]);

      case 5:
        return _list([
          _grid(
            kToppings,
            isSelected: (o) => _bowl.toppings.contains(o),
            onTap: (o) => setState(() {
              if (!_bowl.toppings.remove(o)) _bowl.toppings.add(o);
            }),
          ),
        ]);

      default:
        return _Review(
          bowl: _bowl,
          saveLabel: _reopened ? 'Save as a new recipe' : 'Save this recipe',
          onEdit: (step) => setState(() => _step = step),
          onSave: _saveWithName,
        );
    }
  }

  /// Asks what to call the recipe before saving it. Without a name the list
  /// is a row of identical entries, which is the thing that makes reopening
  /// one feel like it loaded the wrong bowl.
  Future<void> _saveWithName() async {
    final name = await promptForBowlName(
      context,
      initial: _bowl.name.isEmpty ? _bowl.suggestedName : _bowl.name,
      title: _reopened ? 'Save as a new recipe' : 'Name this bowl',
    );
    if (name == null || !mounted) return;

    _bowl.name = name;
    AppScope.of(context).saveBowl(_bowl, name: name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved as "${_bowl.displayName}"')),
    );
  }

  Widget _list(List<Widget> children) => ListView(
        // shrinkWrap so the list is only as tall as its rows; the content
        // then hugs and the footer sits right under it. Still scrolls when
        // the rows are taller than the space available.
        shrinkWrap: true,
        // Tight bottom padding so the last control sits close to the footer
        // instead of leaving an empty band between the menu and the bar.
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.xs),
        children: children,
      );

  /// Two columns of tiles. Ingredients are picked by look as much as by
  /// name, so they get a grid with room for the emoji rather than a list of
  /// rows where every option is the same grey line.
  Widget _grid(
    List<Ingredient> options, {
    required bool Function(Ingredient) isSelected,
    required void Function(Ingredient) onTap,
    bool Function(Ingredient)? available,
  }) =>
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        // Taller than wide: on a short step (toppings has only four) two
        // rows of taller cards fill more of the screen, so there is far
        // less empty space left above the footer.
        childAspectRatio: 0.86,
        children: [
          for (final (index, option) in options.indexed)
            _IngredientTile(
              ingredient: option,
              isSelected: isSelected(option),
              available: available?.call(option) ?? option.inStock,
              energyLabel: _energyLabel(option),
              onTap: () => onTap(option),
              // Spread the bob out of step across the grid.
              bobPhase: (index % 4) / 4,
            ),
        ],
      );
}

/// Each ingredient's own colour. Curated for the ones on the menu so they
/// read right (rice-bowl blue, chilli red, leaf green), and derived from the
/// id for anything added later, so the look scales with the data instead of
/// being styled by hand per screen.
Color ingredientHue(Ingredient i) {
  const curated = <String, Color>{
    'white-rice': Color(0xFF6FA8D6),
    'brown-rice': Color(0xFFD7A53C),
    'noodles': Color(0xFFE0954A),
    'greens': Color(0xFF6FB85E),
    'ahi-tuna': Color(0xFFE2593F),
    'salmon': Color(0xFFE8826B),
    'chicken': Color(0xFFCB7A3B),
    'tofu': Color(0xFFE2C65B),
    'prawn': Color(0xFFE79A78),
    'cucumber': Color(0xFF7FC08A),
    'avocado': Color(0xFF86B24A),
    'mango': Color(0xFFF0A93A),
    'edamame': Color(0xFF8FBE55),
    'corn': Color(0xFFEBC24A),
    'red-onion': Color(0xFFB15FA0),
    'seaweed': Color(0xFF4F9E7A),
    'miso-sesame': Color(0xFFCF9A4A),
    'sriracha-mayo': Color(0xFFE05A3C),
    'ponzu': Color(0xFFE7C24A),
    'sweet-soy': Color(0xFF9A6A3C),
    'sesame': Color(0xFFCBAE6A),
    'crispy-onion': Color(0xFFD79A52),
    'nori': Color(0xFF4F7E6A),
    'chilli-flakes': Color(0xFFE2522F),
  };
  final hit = curated[i.id];
  if (hit != null) return hit;
  // Stable hue from the id, kept at an appetising saturation and lightness.
  final hue = (i.id.hashCode % 360).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.52, 0.58).toColor();
}

/// Out of stock ingredients are shown rather than hidden, so the customer
/// understands why a choice is not available.
///
/// Concept A ("appetite glow"): a big emoji floating on a soft shadow over a
/// radial wash in the ingredient's own colour, bobbing gently at rest. The
/// chosen card lifts off the grid, its glow strengthens and a check appears.
class _IngredientTile extends StatefulWidget {
  const _IngredientTile({
    required this.ingredient,
    required this.isSelected,
    required this.available,
    required this.energyLabel,
    required this.onTap,
    required this.bobPhase,
  });

  final Ingredient ingredient;
  final bool isSelected;
  final bool available;
  final String energyLabel;
  final VoidCallback onTap;

  /// 0..1, so neighbouring cards bob out of step with each other.
  final double bobPhase;

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final hue = ingredientHue(widget.ingredient);
    final outOfStock = !widget.ingredient.inStock;
    final selected = widget.isSelected;

    return Opacity(
      opacity: widget.available ? 1 : 0.5,
      child: GestureDetector(
        onTap: widget.available ? widget.onTap : null,
        onTapDown: widget.available ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            // The lift: the chosen card rises off the grid.
            transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                color: selected ? hue : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? hue.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: selected ? 22 : 6,
                  offset: Offset(0, selected ? 12 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The ingredient-colour wash behind the emoji.
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      opacity: selected ? 0.5 : 0.14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.35),
                            radius: 0.85,
                            colors: [hue, hue.withValues(alpha: 0)],
                            stops: const [0, 0.72],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Floating, bobbing emoji with a soft drop shadow.
                        AnimatedBuilder(
                          animation: _bob,
                          builder: (context, child) {
                            final t = still
                                ? 0.0
                                : sin((_bob.value + widget.bobPhase) *
                                    2 * pi);
                            return Transform.translate(
                              offset: Offset(0, -t * 3),
                              child: child,
                            );
                          },
                          child: AnimatedScale(
                            scale: selected ? 1.12 : 1,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            child: Text(
                              widget.ingredient.emoji,
                              style: TextStyle(
                                fontSize: 38,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.ingredient.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (outOfStock)
                          Text('Out of stock',
                              style: AppTypography.label
                                  .copyWith(color: AppColors.error))
                        else
                          Text(
                            widget.ingredient.price > 0
                                ? '+${formatPrice(widget.ingredient.price)} · ${widget.energyLabel}'
                                : widget.energyLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.secondary,
                          ),
                      ],
                    ),
                  ),
                  // The check badge, in the ingredient's own colour.
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: hue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.bowl,
    required this.onClose,
    required this.onSurprise,
  });

  final int step;
  final String title;
  final String subtitle;
  final Bowl bowl;
  final VoidCallback onClose;
  final VoidCallback onSurprise;

  /// The band is built from the accent rather than from black, but never
  /// from the accent at full brightness: a pale accent would leave white
  /// text unreadable. Lightness is capped, so all five accents and both
  /// themes produce a band deep enough to carry white.
  static Color _band(Color c, double maxLightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(min(hsl.lightness, maxLightness))
        .withSaturation((hsl.saturation * 0.94).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final accent = AppColors.primary;
    const onBand = Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // 0.33 and 0.20: the lightest the band may go and still carry
          // white at 4.5:1. Saffron is the binding case at 4.9:1.
          colors: [_band(accent, 0.33), _band(accent, 0.20)],
        ),
        // A rounded bottom, so the band reads as a self-contained header
        // with the content sitting just below it.
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.radiusSheet)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
              AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('STEP $step OF 6',
                      style: AppTypography.label.copyWith(
                          color: onBand, letterSpacing: 1.4)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onSurprise,
                    icon: const Text('\u{1F3B2}',
                        style: TextStyle(fontSize: 15)),
                    label: Text('Surprise me',
                        style: AppTypography.label.copyWith(
                            color: onBand, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                        foregroundColor: onBand,
                        minimumSize: const Size(0, AppSpacing.minTouchTarget)),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: onBand),
                    tooltip: 'Close the builder',
                    // Align the X to the screen padding (the same right edge as
                    // the title) rather than sitting inset by the default
                    // button padding, which left too big a gap on the right.
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerRight,
                    constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget),
                  ),
                ],
              ),
              Text(title,
                  style: AppTypography.screenTitle
                      .copyWith(color: onBand, fontSize: 26)),
              const SizedBox(height: AppSpacing.xs),
              // Full white, not a dimmed white: on a saffron or green
              // band anything under 95% opacity drops below 4.5:1.
              Text(subtitle,
                  style: AppTypography.secondary
                      .copyWith(color: onBand.withValues(alpha: 0.95))),
              const SizedBox(height: AppSpacing.md),

              // The bowl replaces the six segments, and the ingredients
              // already chosen sit beside it. Progress and what you have
              // made end up on the same line, so the band stays short.
              Row(
                children: [
                  _BowlProgress(progress: step / 6, size: 46),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _PickedChips(bowl: bowl)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bowl that fills as the customer moves through the six steps.
///
/// It replaces a progress bar, so progress reads as the thing being made
/// rather than as an abstract measure of a form being completed.
class _BowlProgress extends StatelessWidget {
  const _BowlProgress({required this.progress, required this.size});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _BowlPainter(fill: value, accent: AppColors.primary),
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  _BowlPainter({required this.fill, required this.accent});

  final double fill;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final cx = w / 2;
    final rimY = h * 0.40;
    final r = w * 0.42;
    final bowlRect = Rect.fromCircle(center: Offset(cx, rimY), radius: r);

    // Lower half of a circle: addArc sweeps clockwise from 3 o'clock, and
    // close() draws the rim back across the top.
    final bowl = Path()
      ..addArc(bowlRect, 0, pi)
      ..close();

    // What is in it so far.
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(bowl);
      final top = rimY + r * (1 - fill);
      canvas.drawRect(
        Rect.fromLTRB(cx - r, top, cx + r, rimY + r),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HSLColor.fromColor(accent)
                  .withLightness(0.78)
                  .toColor()
                  .withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.75),
            ],
          ).createShader(Rect.fromLTRB(cx - r, top, cx + r, rimY + r)),
      );
      canvas.restore();
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2, w * 0.055)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    canvas.drawArc(bowlRect, 0, pi, false, stroke);
    canvas.drawLine(
        Offset(cx - r * 1.12, rimY), Offset(cx + r * 1.12, rimY), stroke);
  }

  @override
  bool shouldRepaint(covariant _BowlPainter old) =>
      old.fill != fill || old.accent != accent;
}

/// The ingredients already chosen, in the order they go into the bowl.
///
/// Four fit; beyond that the rest become a count, because the row has to
/// stay one line however much the customer piles on.
class _PickedChips extends StatelessWidget {
  const _PickedChips({required this.bowl});

  final Bowl bowl;

  static const int _visible = 4;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final picked = bowl.all;
    final shown = picked.take(_visible).toList();
    final extra = picked.length - shown.length;

    Widget shell(Widget child, {bool dashed = false}) => Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: dashed ? 0.06 : 0.16),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard * 0.6),
            border: Border.all(
              color: Colors.white.withValues(alpha: dashed ? 0.28 : 0.34),
            ),
          ),
          child: child,
        );

    return Row(
      children: [
        if (shown.isEmpty)
          shell(
            Text('\u{002B}',
                style: AppTypography.label
                    .copyWith(color: Colors.white.withValues(alpha: 0.6))),
            dashed: true,
          )
        else
          for (final item in shown) ...[
            // A new key makes the chip scale in when that ingredient is
            // added, so picking something is visible up here too.
            TweenAnimationBuilder<double>(
              key: ValueKey(item.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
              child: shell(
                  Text(item.emoji, style: const TextStyle(fontSize: 15))),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        if (extra > 0)
          shell(Text('+$extra',
              style: AppTypography.label.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _CapacityWarning extends StatelessWidget {
  const _CapacityWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.md, AppSpacing.screenPadding, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The bowl is full. Remove something before adding more.',
              style:
                  AppTypography.secondary.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(label, style: AppTypography.secondary),
    );
  }
}

class _PortionToggle extends StatelessWidget {
  const _PortionToggle({required this.large, required this.onChanged});

  final bool large;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        child: SwitchListTile.adaptive(
          value: large,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: Text('Large portion',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('Adds \$3.50 and about 700 kJ',
              style: AppTypography.secondary),
        ),
      ),
    );
  }
}

class _SpiceCard extends StatelessWidget {
  const _SpiceCard({
    required this.spice,
    required this.label,
    required this.onChanged,
  });

  final int spice;
  final String label;
  final ValueChanged<int> onChanged;

  // Heat ramp: Mild -> Medium -> Hot -> Extra hot.
  static const List<Color> _heat = <Color>[
    Color(0xFF8FBE55),
    Color(0xFFE5A32E),
    Color(0xFFE0702C),
    Color(0xFFD23B2A),
  ];
  static const List<String> _emoji = <String>[
    '\u{1F336}',
    '\u{1F336}',
    '\u{1F525}',
    '\u{1F525}',
  ];

  @override
  Widget build(BuildContext context) {
    final Color heat = _heat[spice];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Spice level',
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: heat.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(label,
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w700, color: heat)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: _SpiceKnob(
              spice: spice,
              heat: heat,
              emoji: _emoji[spice],
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mild', style: AppTypography.label),
              Text('Extra hot', style: AppTypography.label),
            ],
          ),
        ],
      ),
    );
  }
}

// A twistable 3D dial. Drag it, or tap anywhere on the face, to set the
// level; the notch and tick ring light up in the current heat colour and the
// pepper grows. Lives only on step 4's spice card.
class _SpiceKnob extends StatelessWidget {
  const _SpiceKnob({
    required this.spice,
    required this.heat,
    required this.emoji,
    required this.onChanged,
  });

  final int spice;
  final Color heat;
  final String emoji;
  final ValueChanged<int> onChanged;

  static const double _size = 128; // hit + tick-ring box
  static const double _body = 104; // metal knob diameter
  static const List<double> _angles = <double>[-120, -40, 40, 120];

  void _handle(Offset local) {
    const double c = _size / 2;
    final double dx = local.dx - c;
    final double dy = local.dy - c;
    // Angle from the top, clockwise. atan2 gives 0 at the right, so +90.
    double deg = atan2(dy, dx) * 180 / pi + 90;
    if (deg > 180) deg -= 360;
    deg = deg.clamp(-120.0, 120.0);
    final int level = ((deg + 120) / 240 * 3).round();
    if (level != spice) onChanged(level);
  }

  @override
  Widget build(BuildContext context) {
    final bool noMotion = MediaQuery.disableAnimationsOf(context);
    final Duration dur =
        noMotion ? Duration.zero : const Duration(milliseconds: 350);
    final Curve curve = noMotion ? Curves.linear : Curves.easeOutBack;

    return GestureDetector(
      onTapDown: (TapDownDetails d) => _handle(d.localPosition),
      onPanStart: (DragStartDetails d) => _handle(d.localPosition),
      onPanUpdate: (DragUpdateDetails d) => _handle(d.localPosition),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tick ring around the knob.
            CustomPaint(
              size: const Size(_size, _size),
              painter: _TickPainter(spice: spice, heat: heat, base: AppColors.border),
            ),
            // Brushed-metal knob body.
            Container(
              width: _body,
              height: _body,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: <Color>[
                    Color(0xFFE9E2D8),
                    Color(0xFFCFC6B8),
                    Color(0xFFE9E2D8),
                    Color(0xFFCFC6B8),
                    Color(0xFFE9E2D8),
                  ],
                  stops: <double>[0, 0.25, 0.5, 0.75, 1],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55281900),
                    blurRadius: 20,
                    offset: Offset(0, 9),
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),
            // Rotating cap carrying the heat-coloured notch.
            AnimatedRotation(
              turns: _angles[spice] / 360,
              duration: dur,
              curve: curve,
              child: Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: <Color>[
                      Color(0xFFFFFDF8),
                      Color(0xFFD7CDBD),
                      Color(0xFFC3B8A6),
                    ],
                    stops: <double>[0, 0.7, 1],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: AnimatedContainer(
                      duration: dur,
                      width: 5,
                      height: 22,
                      decoration: BoxDecoration(
                        color: heat,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Heat glow behind the pepper.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: spice == 0 ? 0 : 0.18 + spice * 0.12,
                duration: dur,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        heat.withValues(alpha: 0.6),
                        heat.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Pepper, upright, grows with heat.
            IgnorePointer(
              child: AnimatedScale(
                scale: 1 + spice * 0.12,
                duration: dur,
                curve: curve,
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.spice,
    required this.heat,
    required this.base,
  });

  final int spice;
  final Color heat;
  final Color base;

  static const int _count = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 4;
    final int lit = (spice / 3 * (_count - 1)).round();
    final Paint p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _count; i++) {
      // Spread the ticks across a 260-degree arc, measured from the top.
      final double a = (-130 + i * (260 / (_count - 1))) * pi / 180;
      final Offset pos = Offset(c.dx + sin(a) * r, c.dy - cos(a) * r);
      p.color = i <= lit ? heat : base;
      canvas.drawCircle(pos, i <= lit ? 3.6 : 3.0, p);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.spice != spice || old.heat != heat || old.base != base;
}

// ----------------------------------------------------------------- review

class _Review extends StatefulWidget {
  const _Review({
    required this.bowl,
    required this.onEdit,
    required this.onSave,
    required this.saveLabel,
  });

  final Bowl bowl;
  final ValueChanged<int> onEdit;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  // The step of the row being touched, or null. Shared across the rows so
  // the one under the finger stays lit while the others dim (the spotlight).
  final ValueNotifier<int?> _active = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bowl = widget.bowl;
    final onEdit = widget.onEdit;
    final onSave = widget.onSave;
    final saveLabel = widget.saveLabel;
    // Saving a recipe needs an account, so a guest never sees the save button.
    final isMember = AppScope.of(context).isMember;
    return ListView(
      // shrinkWrap so the review hugs its rows and the footer sits right
      // under "Send to machine", with no empty space above it.
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('\u{1F963}', style: TextStyle(fontSize: 56)),
              const SizedBox(height: AppSpacing.md),
              Text('${bowl.itemCount} ingredients',
                  style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _Stat(label: 'TOTAL', value: formatPrice(bowl.price)),
                  _Stat(
                      label: 'ENERGY',
                      value: formatKilojoules(bowl.kilojoules)),
                  _Stat(label: 'PREP', value: '${bowl.prepMinutes} min'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Line(
            label: 'Base',
            value: bowl.base?.name ?? 'Not chosen',
            step: 1,
            onEdit: onEdit,
            active: _active),
        _Line(
          label: 'Protein',
          value:
              '${bowl.protein?.name ?? 'Not chosen'} · ${bowl.largePortion ? 'Large' : 'Regular'}',
          step: 2,
          onEdit: onEdit,
          active: _active,
        ),
        _Line(
          label: 'Vegetables',
          value: bowl.vegetables.isEmpty
              ? 'None'
              : bowl.vegetables.map((v) => v.name).join(', '),
          step: 3,
          onEdit: onEdit,
          active: _active,
        ),
        _Line(
          label: 'Sauce',
          value:
              '${bowl.sauce?.name ?? 'Not chosen'} · ${bowl.spiceLabel}',
          step: 4,
          onEdit: onEdit,
          active: _active,
        ),
        _Line(
          label: 'Toppings',
          value: bowl.toppings.isEmpty
              ? 'None'
              : bowl.toppings.map((t) => t.name).join(', '),
          step: 5,
          onEdit: onEdit,
          active: _active,
        ),
        if (isMember) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.bookmark_outline, size: 20),
            label: Text(saveLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.buttonHeight),
              foregroundColor: AppColors.base,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.1)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A review row that lifts when it is touched. "Edit" is hidden at rest and
/// slides in on press, so the resting screen stays clean while touching a row
/// makes it obviously a button — the same lift the ingredient cards use, so
/// the builder reads as one system.
/// Spotlight: while a row is touched it stays lit and grows a little, and
/// the other rows dim. The active step is held by the shared [active]
/// notifier so each row knows whether it is the focused one, a dimmed one, or
/// at rest.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.step,
    required this.onEdit,
    required this.active,
  });

  final String label;
  final String value;
  final int step;
  final ValueChanged<int> onEdit;
  final ValueNotifier<int?> active;

  void _focus() => active.value = step;
  void _release() {
    if (active.value == step) active.value = null;
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    const dur = Duration(milliseconds: 220);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MouseRegion(
        onEnter: (_) => _focus(),
        onExit: (_) => _release(),
        child: GestureDetector(
          onTap: () => onEdit(step),
          onTapDown: (_) => _focus(),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          child: ValueListenableBuilder<int?>(
            valueListenable: active,
            builder: (context, current, _) {
              final isActive = current == step;
              // Some other row is the focus, so this one steps back.
              final isDimmed = current != null && current != step;

              return AnimatedOpacity(
                duration: dur,
                opacity: isDimmed ? 0.5 : 1,
                child: AnimatedScale(
                  duration: dur,
                  curve: Curves.easeOutCubic,
                  scale: isActive ? 1.03 : 1,
                  child: AnimatedContainer(
                    duration: dur,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.border,
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: [
                        if (isActive)
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label.toUpperCase(),
                                  style: AppTypography.label.copyWith(
                                      color: AppColors.textSecondary,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 2),
                              Text(value, style: AppTypography.body),
                            ],
                          ),
                        ),
                        Text('Edit',
                            style: AppTypography.label.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bowl,
    required this.isLast,
    required this.canAdvance,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final Bowl bowl;
  final bool isLast;
  final bool canAdvance;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// Null on the steps where there is nothing to skip: the three required
  /// ones, the review, and an optional step the customer has already made a
  /// choice on, where Skip would read as "throw that away".
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      // Same surface as the content sheet, and no top border. The sheet and
      // the action bar become one continuous panel, so there is no second
      // colour and no seam where they meet — the controls just sit on the
      // same background the cards scroll over.
      color: AppColors.surface,
      // top: false — this bar sits at the bottom, but SafeArea would otherwise
      // re-apply the status-bar inset to its TOP, padding ~44px of empty space
      // above the price/Next row and making the whole container tall. We only
      // want the bottom inset (the home indicator), so the top is switched off.
      child: SafeArea(
        top: false,
        child: Padding(
          // A small gap above the controls so the top edge doesn't look like
          // it's touching the price/Next row, and a matching 6px gap below so
          // the bar lifts off the bottom edge. SafeArea still reserves the home
          // indicator under that. The bar stays compact — just these two hairs.
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 6, AppSpacing.screenPadding, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tight = constraints.maxWidth < 330;
              // Next is anchored to the right and keeps one width across
              // every "Next" step, and the Skip slot before it is reserved
              // whether or not Skip is showing. So the button sits in the
              // same place on a required step as on an optional one — the
              // only thing that changes is whether Skip appears in the gap
              // to its left. The review step is the exception: its label is
              // longer and it never has a Skip, so it takes its own width.
              const barH = 42.0; // minimal control height for a tappable bar
              final skipSlot = tight ? 46.0 : 60.0;
              // Review's button is a little wider than a step's so "Place
              // Order" fits, but kept trim so the price keeps its room.
              final nextWidth = isLast ? 150.0 : (tight ? 118.0 : 134.0);

              return Row(
                children: [
                  InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: barH,
                      height: barH,
                      decoration: BoxDecoration(
                        // Card fill now, so the circle still reads as a
                        // button against the cream bar it sits on.
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(Icons.arrow_back, color: AppColors.base),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Price over energy, two tight lines. Expanded (not Flexible
                  // beside a Spacer) so the price gets all the free width and
                  // shows in full — a Flexible and a Spacer each took flex:1 and
                  // split the space, which clipped the price to "$16…".
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatPrice(bowl.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle.copyWith(
                                fontWeight: FontWeight.w700, height: 1.1)),
                        Text(formatKilojoules(bowl.kilojoules),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.secondary.copyWith(height: 1.1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The reserved Skip slot. Present on every step except the
                  // review, empty when this step has nothing to skip, so
                  // Next never shifts.
                  if (!isLast) ...[
                    SizedBox(
                      width: skipSlot,
                      child: onSkip == null
                          ? null
                          : Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: onSkip,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  minimumSize: const Size(0, barH),
                                  // Match the Next button's height exactly.
                                  // Without this the button keeps its default
                                  // 48px tap target, which is taller than barH
                                  // and makes the whole bar grow (and shift up)
                                  // only on steps where Skip is shown.
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text('Skip',
                                    style: AppTypography.secondary.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  SizedBox(
                    width: nextWidth,
                    height: barH,
                    child: ElevatedButton(
                      onPressed: canAdvance ? onNext : null,
                      // minimumSize (0, barH) overrides the theme's 56 so the
                      // button is the shorter bar height; colours stay null on
                      // a Next step so the theme's accent still applies.
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, barH),
                        backgroundColor: isLast ? AppColors.success : null,
                        foregroundColor: isLast ? Colors.white : null,
                      ),
                      child: Text(isLast ? 'Place Order' : 'Next',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
