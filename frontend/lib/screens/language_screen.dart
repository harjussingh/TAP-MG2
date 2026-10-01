import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/settings_widgets.dart';

/// Each language is listed in its own script first, with the English name
/// underneath. Someone looking for their language recognises it by its own
/// name, not by the English one.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
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
                Text(S.t('language'), style: AppTypography.sectionHeading),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                    AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xxxl),
                children: [
                  Text(S.t('chooseLanguage'), style: AppTypography.screenTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(S.t('languageHint'), style: AppTypography.secondary),
                  const SizedBox(height: AppSpacing.xl),
                  for (final language in AppLanguage.values)
                    _LanguageRow(
                      language: language,
                      selected: language == settings.language,
                      onTap: () => setState(() => settings.setLanguage(language)),
                    ),
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

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(language.nativeName,
                          style: AppTypography.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(language.englishName,
                          style: AppTypography.secondary),
                    ],
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: Icon(Icons.check,
                        size: 16, color: AppColors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
