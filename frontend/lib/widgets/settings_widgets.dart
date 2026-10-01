import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The dark mode card. The sun and moon swap places rather than a plain
/// switch, because the control is also the illustration of what it does.
class DarkModeCard extends StatefulWidget {
  const DarkModeCard({super.key});

  @override
  State<DarkModeCard> createState() => _DarkModeCardState();
}

class _DarkModeCardState extends State<DarkModeCard> {
  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final on = settings.darkMode;
    return Semantics(
      toggled: on,
      button: true,
      label: S.t('darkMode'),
      child: InkWell(
        onTap: () => setState(settings.toggleDarkMode),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
                color: on ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                ),
                child: Icon(on ? Icons.dark_mode : Icons.light_mode,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t('darkMode'),
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(on ? S.t('darkModeOn') : S.t('darkModeOff'),
                        style: AppTypography.secondary),
                  ],
                ),
              ),
              _SunMoon(on: on),
            ],
          ),
        ),
      ),
    );
  }
}

class _SunMoon extends StatelessWidget {
  const _SunMoon({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      width: 64,
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: on
            ? AppColors.primary.withValues(alpha: 0.22)
            : AppColors.border,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.card,
            shape: BoxShape.circle,
          ),
          child: Icon(
            on ? Icons.nightlight_round : Icons.wb_sunny_outlined,
            size: 16,
            color: on ? AppColors.onPrimary : AppColors.base,
          ),
        ),
      ),
    );
  }
}

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key, this.trailing});

  final String text;

  /// The current value, shown on the right the way the reference does.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text,
              style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 1.2)),
          if (trailing != null)
            Text(trailing!,
                style: AppTypography.label
                    .copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: AppTypography.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsToggle extends StatefulWidget {
  const SettingsToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  State<SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<SettingsToggle> {
  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              ),
              child: Icon(widget.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(widget.subtitle, style: AppTypography.secondary),
                ],
              ),
            ),
            Switch(
              value: widget.value,
              onChanged: widget.enabled
                  ? (v) => setState(() => widget.onChanged(v))
                  : null,
              activeThumbColor: AppColors.onPrimary,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar the reference shows along the bottom: how many things have moved,
/// with a way back and a way forward. It slides in only once something has
/// actually changed.
class ChangeBar extends StatefulWidget {
  const ChangeBar({super.key});

  @override
  State<ChangeBar> createState() => _ChangeBarState();
}

class _ChangeBarState extends State<ChangeBar> {
  Future<void> _review() async {
    final summary = settings.changeSummary;
    final keep = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusCard * 1.5)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('reviewChanges'),
                  style: AppTypography.sectionHeading),
              const SizedBox(height: AppSpacing.lg),
              if (summary.isEmpty)
                Text(S.t('noChanges'), style: AppTypography.secondary)
              else
                for (final line in summary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child:
                                Text(line, style: AppTypography.body)),
                      ],
                    ),
                  ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('keepChanges')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel')),
              ),
            ],
          ),
        ),
      ),
    );

    if (keep == true) {
      await settings.commit();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final count = settings.changeCount;

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$count ${count == 1 ? S.t('change') : S.t('changes')}',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(settings.discard),
                    child: Text(S.t('discard'),
                        style: AppTypography.body
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ElevatedButton(
                    onPressed: _review,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.minTouchTarget),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                    ),
                    child: Text(S.t('review')),
                  ),
                ],
              ),
            ),
    );
  }
}
