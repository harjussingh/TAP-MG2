import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dining_room_scene.dart';
import 'home_shell.dart';

/// Which table the customer is sitting at.
///
/// The room is drawn across the top and the number appears on the card
/// standing on the table in it, so what is on screen matches what is on the
/// table in front of them. Same shape as the sign-in screen: illustration
/// above, white sheet curving over it below.
class TableNumberScreen extends StatefulWidget {
  const TableNumberScreen({super.key});

  @override
  State<TableNumberScreen> createState() => _TableNumberScreenState();
}

class _TableNumberScreenState extends State<TableNumberScreen>
    with TickerProviderStateMixin {
  String _value = '';

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  /// One slow loop for the room: the lamp sways, the light shifts and the
  /// machine blinks off it.
  late final AnimationController _room = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  /// Fires once per digit, which makes the card on the table react.
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  @override
  void dispose() {
    _intro.dispose();
    _room.dispose();
    _land.dispose();
    super.dispose();
  }

  bool get _ready => _value.isNotEmpty;

  void _press(String key) {
    if (key == 'del') {
      if (_value.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _value = _value.substring(0, _value.length - 1));
      return;
    }

    // Three digits is the ceiling, and a leading zero is not a table, so both
    // are refused with a bump rather than accepted and rejected later.
    if (_value.length >= 3 || (_value.isEmpty && key == '0')) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _value += key);
    _land.forward(from: 0);
  }

  void _enterApp(OrderType type) {
    final state = AppScope.of(context);
    state.setOrderType(type);
    state.setTableNumber(type == OrderType.dineIn ? _value.padLeft(2, '0') : '');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  Widget _stagger(double start, Widget child, {double rise = 20}) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
            offset: Offset(0, rise * (1 - curve.value)), child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final scale = settings.textScale.factor;

    return Scaffold(
      // Matches the sheet, so the strip it is lifted over is invisible.
      backgroundColor: AppColors.card,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The sheet is measured rather than guessed, so the keypad sits
          // directly above the button with nothing left over underneath it.
          const gutter = AppSpacing.screenPadding;
          const gap = AppSpacing.sm;
          const overlap = AppSpacing.xl;
          const minScene = 168.0;

          final keyWidth = (constraints.maxWidth - gutter * 2 - gap * 2) / 3;

          // The home indicator. The body is not inside a SafeArea, so the
          // sheet keeps its own last row clear of it.
          final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

          // Everything in the sheet that is not the keypad.
          final titleBlock = 44 * scale;
          final fixed = AppSpacing.lg + // top padding
              titleBlock +
              AppSpacing.lg + // gap under the title
              AppSpacing.md + // gap above the button
              AppSpacing.buttonHeight +
              AppSpacing.minTouchTarget + // the takeaway link
              AppSpacing.sm + // bottom padding
              safeBottom;

          // Keys take their natural height unless the screen is too short,
          // in which case they flatten rather than overflow.
          final roomForPad = constraints.maxHeight - minScene - fixed;
          final naturalPad = (keyWidth / 1.9) * 4 + gap * 3;
          final padHeight = math.min(naturalPad, math.max(roomForPad, 128.0));
          final keyHeight = (padHeight - gap * 3) / 4;

          // `overlap` lifts the sheet when it is painted, which does not
          // shrink its box, so the box must still get its full height.
          final sheetHeight = fixed + padHeight;
          final sceneHeight = (constraints.maxHeight - sheetHeight)
              .clamp(minScene, constraints.maxHeight * 0.62);

          return Column(
            children: [
              SizedBox(
                height: sceneHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_room, _land]),
                        builder: (context, _) => DiningRoomScene(
                          value: _value,
                          t: _room.value,
                          landed: _land.value,
                          still: still,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _stagger(0.00, const _BackButton(), rise: 8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -overlap),
                  child: _stagger(
                    0.10,
                    _sheet(
                      keyWidth: keyWidth,
                      keyHeight: keyHeight,
                      safeBottom: safeBottom,
                    ),
                    rise: 26,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sheet({
    required double keyWidth,
    required double keyHeight,
    required double safeBottom,
  }) {
    final radius = BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSheet));

    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.lg,
              AppSpacing.screenPadding, AppSpacing.sm + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Which table are you at?',
                  style: AppTypography.cardTitle
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('It is on the card standing on your table',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              _Keypad(
                onKey: _press,
                keyWidth: keyWidth,
                keyHeight: keyHeight,
              ),
              const SizedBox(height: AppSpacing.md),
              _Confirm(
                ready: _ready,
                value: _value,
                onTap: () => _enterApp(OrderType.dineIn),
              ),
              TextButton(
                onPressed: () => _enterApp(OrderType.takeaway),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minTouchTarget)),
                child: Text("I'm ordering takeaway",
                    style: AppTypography.secondary.copyWith(
                        color: AppColors.base, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ parts

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            child: Icon(Icons.arrow_back, size: 21, color: AppColors.base),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onKey,
    required this.keyWidth,
    required this.keyHeight,
  });

  final ValueChanged<String> onKey;
  final double keyWidth;
  final double keyHeight;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < _rows.length; r++) ...[
          Row(
            children: [
              for (var c = 0; c < 3; c++) ...[
                SizedBox(
                  width: keyWidth,
                  height: keyHeight,
                  child: _rows[r][c].isEmpty
                      ? null
                      : _Key(
                          label: _rows[r][c],
                          onTap: () => onKey(_rows[r][c]),
                        ),
                ),
                if (c < 2) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          if (r < _rows.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Dips under the finger and sends a ring out from where it was pressed,
/// which is what makes a flat rectangle feel struck rather than tapped.
class _Key extends StatefulWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  bool _down = false;

  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDelete = widget.label == 'del';

    return Semantics(
      button: true,
      label: isDelete ? 'Delete last digit' : widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          _ripple.forward(from: 0);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 90),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) {
                  if (_ripple.value == 0 || _ripple.isCompleted) {
                    return const SizedBox.shrink();
                  }
                  final p = Curves.easeOut.transform(_ripple.value);
                  return IgnorePointer(
                    child: Container(
                      width: 40 + p * 70,
                      height: 40 + p * 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: (1 - p) * 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _down
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(
                      color: _down ? AppColors.primary : AppColors.border),
                ),
                child: isDelete
                    ? Icon(Icons.backspace_outlined,
                        size: 21, color: AppColors.base)
                    : Text(widget.label,
                        style: AppTypography.sectionHeading.copyWith(
                            fontSize: 24, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.ready,
    required this.value,
    required this.onTap,
  });

  final bool ready;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      decoration: BoxDecoration(
        color: ready ? AppColors.primary : AppColors.disabled,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: ready
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ready ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ready ? 'Confirm table $value' : 'Enter your table',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        ready ? AppColors.onPrimary : AppColors.textSecondary,
                  ),
                ),
                if (ready) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.arrow_forward,
                      size: 19, color: AppColors.onPrimary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
