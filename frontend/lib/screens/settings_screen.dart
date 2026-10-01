import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/settings_widgets.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'notification_settings_screen.dart';

/// The settings hub.
///
/// Changes apply live so the person sees them, and the bar at the bottom
/// tracks what has moved since they arrived. Nothing is lost either way:
/// Discard puts it all back, Review shows what they did before keeping it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.base),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0,
                    AppSpacing.screenPadding, AppSpacing.xxxl),
                children: [
                  Text(S.t('settings'), style: AppTypography.screenTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(S.t('settingsSubtitle'),
                      style: AppTypography.secondary),
                  const SizedBox(height: AppSpacing.xl),

                  const DarkModeCard(),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('personalisation')),
                  SettingsRow(
                    icon: Icons.palette_outlined,
                    title: S.t('appearance'),
                    subtitle: settings.appearanceSummary,
                    onTap: () => _open(const AppearanceScreen()),
                  ),
                  SettingsRow(
                    icon: Icons.translate,
                    title: S.t('language'),
                    subtitle: settings.language.nativeName,
                    onTap: () => _open(const LanguageScreen()),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SettingsSectionLabel(S.t('alerts')),
                  SettingsRow(
                    icon: Icons.notifications_outlined,
                    title: S.t('notifications'),
                    subtitle: _notificationSummary(),
                    onTap: () => _open(const NotificationSettingsScreen()),
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

  String _notificationSummary() {
    if (!settings.pushNotifications) return 'Off';
    final on = [
      if (settings.messageAlerts) S.t('orderUpdates'),
      if (settings.promotionAlerts) S.t('offers'),
    ];
    return on.isEmpty ? 'Push only' : on.join(' \u00b7 ');
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }
}
