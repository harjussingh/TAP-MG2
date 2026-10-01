import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/state_views.dart';
import 'account_detail_screens.dart';
import 'edit_details_screen.dart';
import 'order_tracking_screen.dart';
import 'qr_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'review_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);

    if (state.history.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: "You haven't ordered yet",
        message: 'Your past orders will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: state.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (context, index) {
        final order = state.history[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('#${order.id}', style: AppTypography.cardTitle),
                  Text(formatPrice(order.total),
                      style: AppTypography.cardTitle
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${order.stage.title} \u00b7 ${order.type.label}'
                '${order.tableNumber.isEmpty ? '' : ' \u00b7 Table ${order.tableNumber}'}',
                style: AppTypography.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => OrderTrackingScreen(order: order)),
                    ),
                    child: const Text('Track'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (order.rating == null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ReviewScreen(order: order)),
                      ),
                      child: const Text('Leave a review'),
                    )
                  else
                    Row(
                      children: [
                        for (var i = 0; i < order.rating!; i++)
                          Icon(Icons.star,
                              size: 18, color: AppColors.primary),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Saved recipes are a member feature, so a guest sees a prompt rather than
/// an empty list of something they cannot use.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);

    // Guests never reach this screen: the Saved destination is absent from
    // their navigation. The check stays only as a guard.
    if (!state.isMember) return const SizedBox.shrink();

    if (state.savedBowls.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bookmark_outline,
        title: 'No saved bowls yet',
        message: 'Save a bowl from the last step of the builder.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: state.savedBowls.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (context, index) {
        final bowl = state.savedBowls[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          child: Row(
            children: [
              EmojiTile(
                  emoji: '\u{1F963}', colour: AppColors.tileBlue, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My bowl ${index + 1}',
                        style: AppTypography.cardTitle),
                    Text(bowl.summary, style: AppTypography.secondary),
                  ],
                ),
              ),
              Text(formatPrice(bowl.price),
                  style: AppTypography.cardTitle
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final member = state.isMember;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Text(member ? (state.profile?.initial ?? 'M') : 'G',
                  style: AppTypography.sectionHeading),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member ? (state.profile?.name ?? 'Member') : 'Guest',
                    style: AppTypography.sectionHeading),
                Text(member ? (state.profile?.email ?? 'Full access') : 'Limited access',
                    style: AppTypography.secondary),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // A guest has no profile record, so the app offers the upgrade
        // instead of showing account rows that would not work.
        if (!member)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.tileCream,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep your orders',
                    style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Guest orders are not saved. Create an account to keep your '
                  'history, save recipes and use member offers.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => _open(
                    context,
                    const AuthScreen(
                      mode: AuthMode.signUp,
                      linkGuestOrders: true,
                      continueToTable: false,
                    ),
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),

        // Appearance and language are not member features, so a guest gets
        // them too.
        if (!member)
          _Tile(
            icon: Icons.tune,
            label: 'Settings',
            onTap: () => _open(context, const SettingsScreen()),
          ),

        if (member) ...[
          _Tile(
            icon: Icons.person_outline,
            label: 'Edit personal details',
            onTap: () => _open(context, const EditDetailsScreen()),
          ),
          // Saved addresses and saved payment methods have no endpoints in
          // the API, so they are not offered. See INTEGRATION_CHECK.md 3.5.
          _Tile(
            icon: Icons.tune,
            label: 'Settings',
            onTap: () => _open(context, const SettingsScreen()),
          ),
          _Tile(
            icon: Icons.eco_outlined,
            label: 'Dietary preferences',
            onTap: () => _open(context, const DietaryPreferencesScreen()),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => _open(context, const NotificationsScreen()),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => _confirmSignOut(context),
            child: const Text('Log out'),
          ),
        ],
      ],
    );
  }
}

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Signing out clears the session and returns to the entry screen. Leaving
/// the user inside the app as a guest would be wrong: they did not choose to
/// continue as a guest, they chose to leave.
Future<void> _confirmSignOut(BuildContext context) async {
  final state = AppScope.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Log out?'),
      content: Text(
        'You will be returned to the start. Anything in your cart is cleared.',
        style: AppTypography.body,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay logged in')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out')),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  state.signOut();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const QrScreen()),
    (route) => false,
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.base),
        title: Text(label, style: AppTypography.body),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
