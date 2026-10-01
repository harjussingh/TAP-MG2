import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dietary preferences filter the menu and warn on allergens.
class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  static const _options = [
    'Vegetarian',
    'Vegan',
    'Gluten free',
    'Dairy free',
    'Nut allergy',
    'Shellfish allergy',
  ];

  late final Set<String> _selected =
      Set<String>.from(AppScope.of(context).profile?.dietary ?? <String>{});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Dietary preferences')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text(
            'We use these to flag allergens on a bowl before it is sent to the '
            'machine.',
            style: AppTypography.secondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final option in _options)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
              child: CheckboxListTile(
                value: _selected.contains(option),
                activeColor: AppColors.primary,
                checkColor: AppColors.onPrimary,
                title: Text(option, style: AppTypography.body),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _selected.add(option);
                  } else {
                    _selected.remove(option);
                  }
                }),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              final state = AppScope.of(context);
              final profile = state.profile;
              if (profile != null) {
                profile.dietary
                  ..clear()
                  ..addAll(_selected);
                state.updateProfile(profile);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preferences saved')),
              );
              Navigator.pop(context);
            },
            child: const Text('Save preferences'),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late bool _orders = AppScope.of(context).profile?.orderUpdates ?? true;
  late bool _marketing =
      AppScope.of(context).profile?.marketingEmails ?? false;

  void _persist() {
    final state = AppScope.of(context);
    final profile = state.profile;
    if (profile != null) {
      profile
        ..orderUpdates = _orders
        ..marketingEmails = _marketing;
      state.updateProfile(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Switch(
            title: 'Order updates',
            subtitle: 'Tells you when your bowl is ready for collection.',
            value: _orders,
            onChanged: (v) => setState(() {
              _orders = v;
              _persist();
            }),
          ),
          _Switch(
            title: 'Offers and news',
            subtitle: 'Occasional emails about new bowls and member offers.',
            value: _marketing,
            onChanged: (v) => setState(() {
              _marketing = v;
              _persist();
            }),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        title: Text(title, style: AppTypography.body),
        subtitle: Text(subtitle, style: AppTypography.secondary),
      ),
    );
  }
}

