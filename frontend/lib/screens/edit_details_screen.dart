import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The page the client asked for at the second meeting. Australian formats
/// throughout: 04XX XXX XXX phone numbers and DD/MM/YYYY dates.
class EditDetailsScreen extends StatefulWidget {
  const EditDetailsScreen({super.key});

  @override
  State<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends State<EditDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  UserProfile? _draft;
  bool _busy = false;
  bool _dirty = false;

  /// Reading AppScope needs an inherited widget lookup, which is not allowed
  /// in initState. didChangeDependencies runs straight after and is the
  /// correct place for it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;

    final profile =
        AppScope.of(context).profile ?? UserProfile(name: '', email: '');
    _draft = profile.copy();

    _name.text = profile.name;
    _email.text = profile.email;
    _phone.text = profile.phone;

    // Listeners are attached after the initial text, so filling the form
    // does not mark it dirty.
    for (final c in [_name, _email, _phone]) {
      c.addListener(() {
        if (!_dirty && mounted) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requireText(String? v, String field) =>
      (v ?? '').trim().isEmpty ? 'Enter your $field' : null;

  String? _validatePhone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // optional
    if (!digits.startsWith('04') || digits.length != 10) {
      return 'Australian mobiles are 10 digits starting 04';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    // TODO(backend): PATCH the profile, then apply the server's response.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final draft = _draft!
      ..name = _name.text.trim()
      ..email = _email.text.trim()
      ..phone = _phone.text.trim();
    AppScope.of(context).updateProfile(draft);

    setState(() {
      _busy = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your details were saved')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Edit personal details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _Field(
              label: 'Full name',
              controller: _name,
              validator: (v) => _requireText(v, 'name'),
            ),
            // The API does not accept an email change on PATCH /users/me,
            // so it is shown but not editable.
            _ReadOnly(label: 'Email address', value: _email.text),
            _Field(
              label: 'Phone number',
              controller: _phone,
              keyboardType: TextInputType.phone,
              hint: '04XX XXX XXX',
              validator: _validatePhone,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your email address, membership number and join date '
                      'cannot be changed here.',
                      style: AppTypography.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              // Disabled until something actually changes.
              onPressed: (!_dirty || _busy) ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: AppSpacing.inputHeight,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(value,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: AppTypography.body,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
