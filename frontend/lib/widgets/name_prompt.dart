import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Asks the customer what to call a bowl.
///
/// Used both when a recipe is first saved and when it is renamed later, so
/// the two paths cannot drift apart. Returns the trimmed name, or null if
/// the customer backed out. An empty string is a real answer meaning "no
/// name", and the list then falls back to the ingredients.
Future<String?> promptForBowlName(
  BuildContext context, {
  required String initial,
  String title = 'Name this bowl',
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: initial, title: title),
    );

/// A StatefulWidget rather than a controller created beside showDialog,
/// because the controller has to outlive the pop animation and be disposed
/// only once the field is gone.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      // The suggestion arrives selected, so typing replaces it and nobody
      // has to clear it first.
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initial.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      title: Text(widget.title, style: AppTypography.cardTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        maxLength: 40,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Friday lunch',
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
