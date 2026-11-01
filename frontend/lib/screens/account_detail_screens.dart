import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dietary preferences filter the menu and warn on allergens. They are saved
/// to the account, as the API's dietary preferences and allergens.
class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  /// Label, whether it is an allergen (rather than a diet), and API value.
  static const _options = [
    ('Vegetarian', false, 'vegetarian'),
    ('Vegan', false, 'vegan'),
    ('Gluten free', false, 'gluten_free'),
    ('Dairy free', false, 'dairy_free'),
    ('Nut allergy', true, 'peanut'),
    ('Shellfish allergy', true, 'shellfish'),
  ];

  late final Set<String> _dietary =
      Set<String>.from(AppScope.read(context).profile?.dietary ?? <String>{});
  late final Set<String> _allergens =
      Set<String>.from(AppScope.read(context).profile?.allergens ?? <String>{});
  bool _busy = false;

  Set<String> _setFor(bool allergen) => allergen ? _allergens : _dietary;

  Future<void> _save() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.read(context)
          .updateProfile(dietary: _dietary, allergens: _allergens);
      messenger.showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
      if (mounted) setState(() => _busy = false);
    }
  }

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
          for (final (label, allergen, value) in _options)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
              child: CheckboxListTile(
                value: _setFor(allergen).contains(value),
                activeColor: AppColors.primary,
                checkColor: AppColors.onPrimary,
                title: Text(label, style: AppTypography.body),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _setFor(allergen).add(value);
                  } else {
                    _setFor(allergen).remove(value);
                  }
                }),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save preferences'),
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
  late bool _orders = AppScope.read(context).profile?.orderUpdates ?? true;
  late bool _marketing =
      AppScope.read(context).profile?.marketingEmails ?? false;

  /// Offers and news is the account's marketing opt-in, so it is saved to
  /// the server; order updates are a setting on this device.
  Future<void> _setMarketing(bool value) async {
    setState(() => _marketing = value);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.read(context).updateProfile(marketing: value);
    } catch (e) {
      if (mounted) setState(() => _marketing = !value);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
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
            onChanged: (v) {
              setState(() => _orders = v);
              AppScope.read(context).setOrderUpdates(v);
            },
          ),
          _Switch(
            title: 'Offers and news',
            subtitle: 'Occasional emails about new bowls and member offers.',
            value: _marketing,
            onChanged: _setMarketing,
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
