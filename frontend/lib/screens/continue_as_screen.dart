import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'auth_screen.dart';
import 'table_number_screen.dart';

/// Choosing a route here sets the role for the rest of the session, so the
/// app and the access rules never disagree.
class ContinueAsScreen extends StatelessWidget {
  const ContinueAsScreen({super.key});

  /// A member signs in first; the role is set by a successful login rather
  /// than by tapping the button. A guest continues straight through.
  void _member(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
    );
  }

  void _guest(BuildContext context) {
    AppScope.of(context).setRole(UserRole.guest);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TableNumberScreen()),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                AppSpacing.xxl, AppSpacing.screenPadding, AppSpacing.xxl),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const RobomosWordmark(size: 56),
                  const SizedBox(height: AppSpacing.md),
                  Text('How would you\nlike to continue?',
                      textAlign: TextAlign.center,
                      style: AppTypography.screenTitle.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _member(context),
                      child: const Text('Log in as a member'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton(
                      onPressed: () => _guest(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        foregroundColor: AppColors.base,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusCard),
                        ),
                      ),
                      child: Text('Continue as a guest',
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Guest orders are not saved',
                      style: AppTypography.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
