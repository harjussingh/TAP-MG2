import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/settings_widgets.dart';

/// Theme colour, text size and corner style, each applying the moment it is
/// tapped so the choice can be judged rather than imagined.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  @override
  void initState() {
    super.initState();
    settings.beginEditing();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: AppColors.base),
                ),
                Text(S.t('appearance'), style: AppTypography.sectionHeading),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                    AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xxxl),
                children: [
                  const DarkModeCard(),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('themeColour'),
                      trailing: settings.accent.label),
                  const SizedBox(height: AppSpacing.md),
                  _AccentRow(onPicked: () => setState(() {})),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('textSize'),
                      trailing: settings.textScale.label),
                  const SizedBox(height: AppSpacing.md),
                  _TextSizeRow(onPicked: () => setState(() {})),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('uiStyle'),
                      trailing: settings.uiStyle.label),
                  const SizedBox(height: AppSpacing.md),
                  _UiStyleRow(onPicked: () => setState(() {})),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('preview').toUpperCase()),
                  const SizedBox(height: AppSpacing.md),
                  const _Preview(),
                ],
              ),
            ),
            const ChangeBar(),
          ],
        ),
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Row(
      children: [
        for (final accent in AccentColour.values) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: accent == settings.accent,
              label: accent.label,
              child: InkWell(
                onTap: () {
                  settings.setAccent(accent);
                  onPicked();
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: SizedBox(
                  height: AppSpacing.minTouchTarget + 8,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      width: accent == settings.accent ? 44 : 38,
                      height: accent == settings.accent ? 44 : 38,
                      decoration: BoxDecoration(
                        color: accent.colour,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent == settings.accent
                              ? AppColors.base
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: accent == settings.accent
                          ? Icon(Icons.check,
                              size: 20, color: accent.onColour)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextSizeRow extends StatelessWidget {
  const _TextSizeRow({required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Row(
      children: [
        for (final scale in TextScale.values) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: InkWell(
                onTap: () {
                  settings.setTextScale(scale);
                  onPicked();
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scale == settings.textScale
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusInput),
                    border: Border.all(
                      color: scale == settings.textScale
                          ? AppColors.primary
                          : AppColors.border,
                      width: scale == settings.textScale ? 1.6 : 1,
                    ),
                  ),
                  // Each swatch is drawn at the size it represents.
                  child: Text('Aa',
                      style: AppTypography.body.copyWith(
                        fontSize: 13 + (scale.index * 3.5),
                        fontWeight: scale == settings.textScale
                            ? FontWeight.w700
                            : FontWeight.w400,
                      )),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UiStyleRow extends StatelessWidget {
  const _UiStyleRow({required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Row(
      children: [
        for (final style in UiStyle.values) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: InkWell(
                onTap: () {
                  settings.setUiStyle(style);
                  onPicked();
                },
                borderRadius: BorderRadius.circular(style.input),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(style.input),
                    border: Border.all(
                      color: style == settings.uiStyle
                          ? AppColors.primary
                          : AppColors.border,
                      width: style == settings.uiStyle ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // A miniature of the corner treatment it applies.
                      Container(
                        height: 26,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(style.card * 0.6),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(style.label,
                          style: AppTypography.label.copyWith(
                            fontWeight: style == settings.uiStyle
                                ? FontWeight.w700
                                : FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A real card in the current settings, so the choices can be judged against
/// something the person will actually see rather than a swatch.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tilePink,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: const Text('\u{1F41F}', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Robo Classic', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text('Salmon, avocado, cucumber',
                    style: AppTypography.secondary),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text('Add to order',
                          style: AppTypography.label.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('\$18.90', style: AppTypography.cardTitle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
