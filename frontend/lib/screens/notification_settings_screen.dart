import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/settings_widgets.dart';

/// Alert preferences.
///
/// The per-alert switches depend on push being on, so they dim and stop
/// responding when it is off rather than pretending to work.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    settings.beginEditing();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final push = settings.pushNotifications;

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
                Text(S.t('notifications'),
                    style: AppTypography.sectionHeading),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                    AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xxxl),
                children: [
                  SettingsToggle(
                    icon: Icons.notifications_active_outlined,
                    title: S.t('pushNotifications'),
                    subtitle: S.t('pushNotificationsHint'),
                    value: push,
                    onChanged: (v) =>
                        setState(() => settings.setPushNotifications(v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSectionLabel(S.t('notifyMeAbout')),
                  SettingsToggle(
                    icon: Icons.receipt_long_outlined,
                    title: S.t('orderUpdates'),
                    subtitle: S.t('orderUpdatesHint'),
                    value: settings.messageAlerts,
                    enabled: push,
                    onChanged: (v) =>
                        setState(() => settings.setMessageAlerts(v)),
                  ),
                  SettingsToggle(
                    icon: Icons.local_offer_outlined,
                    title: S.t('offers'),
                    subtitle: S.t('offersHint'),
                    value: settings.promotionAlerts,
                    enabled: push,
                    onChanged: (v) =>
                        setState(() => settings.setPromotionAlerts(v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSectionLabel(S.t('soundAndVibration')),
                  SettingsToggle(
                    icon: Icons.volume_up_outlined,
                    title: S.t('sound'),
                    subtitle: S.t('soundHint'),
                    value: settings.sound,
                    enabled: push,
                    onChanged: (v) => setState(() => settings.setSound(v)),
                  ),
                  SettingsToggle(
                    icon: Icons.vibration,
                    title: S.t('vibration'),
                    subtitle: S.t('vibrationHint'),
                    value: settings.vibration,
                    enabled: push,
                    onChanged: (v) => setState(() => settings.setVibration(v)),
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
