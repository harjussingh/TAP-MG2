import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'home_shell.dart';

/// Because there is one QR code for the premises, the table is typed here.
/// The confirmation step is the mitigation for a mistyped number.
class TableNumberScreen extends StatefulWidget {
  const TableNumberScreen({super.key});

  @override
  State<TableNumberScreen> createState() => _TableNumberScreenState();
}

class _TableNumberScreenState extends State<TableNumberScreen> {
  String _value = '';

  void _press(String key) {
    setState(() {
      if (key == 'del') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (_value.length < 3) {
        _value += key;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.header,
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const RobomosWordmark(size: 52),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Which table are you at?',
                      style:
                          AppTypography.screenTitle.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _value.isEmpty ? 'Enter table number' : _value,
                      style: _value.isEmpty
                          ? AppTypography.body
                              .copyWith(color: AppColors.textSecondary)
                          : AppTypography.screenTitle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(child: _Keypad(onKey: _press)),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Disabled until a number is entered.
                      onPressed:
                          _value.isEmpty ? null : () => _enterApp(OrderType.dineIn),
                      child: const Text('Confirm table'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _enterApp(OrderType.takeaway),
                    child: Text("I'm not dining in",
                        style: AppTypography.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else
            Material(
              color: key == 'del' ? AppColors.border : AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: InkWell(
                onTap: () => onKey(key),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                child: Center(
                  child: key == 'del'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(key, style: AppTypography.sectionHeading),
                ),
              ),
            ),
      ],
    );
  }
}
