import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/bowl.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dish_card.dart';
import '../widgets/name_prompt.dart';
import '../widgets/state_views.dart';
import 'account_detail_screens.dart';
import 'auth_screen.dart';
import 'bowl_builder_screen.dart';
import 'cart_screen.dart';
import 'edit_details_screen.dart';
import 'order_tracking_screen.dart';
import 'intro_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// A member's orders come from their account; a guest's from the orders
/// placed on this device.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !AppScope.read(context).historyLoaded) _load();
    });
  }

  Future<void> _load() async {
    try {
      await AppScope.read(context).loadHistory();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _reorder(Order order) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await state.reorder(order.id);
      final skipped = result.skipped.isEmpty
          ? ''
          : ' ${result.skipped.join(', ')} ${result.skipped.length == 1 ? 'is' : 'are'} unavailable.';
      messenger.showSnackBar(SnackBar(
          content: Text('Added ${result.added} item'
              '${result.added == 1 ? '' : 's'} to your cart.$skipped')));
      navigator
          .push(MaterialPageRoute<void>(builder: (_) => const CartScreen()));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);

    if (!state.historyLoaded && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && state.history.isEmpty) {
      return ErrorStateView(
        title: "We couldn't load your orders",
        message: _error!,
        onRetry: _load,
      );
    }
    if (state.history.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: "You haven't ordered yet",
        message: state.isMember
            ? 'Your past orders will appear here.'
            : 'Orders you place on this device will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
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
                    Text(order.number, style: AppTypography.cardTitle),
                    Text(formatCents(order.pricing.totalCents),
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${order.status.title} · ${order.placeLabel}',
                  style: AppTypography.secondary,
                ),
                Text(
                  order.items
                      .map((l) =>
                          l.quantity > 1 ? '${l.quantity} × ${l.name}' : l.name)
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => OrderTrackingScreen(order: order)),
                      ),
                      child: const Text('Track'),
                    ),
                    if (state.isMember)
                      OutlinedButton(
                        onPressed: () => _reorder(order),
                        child: const Text('Reorder'),
                      ),
                    if (order.canReview)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ReviewScreen(order: order)),
                        ),
                        child: const Text('Leave a review'),
                      )
                    else if (order.hasReview)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 18, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Reviewed', style: AppTypography.secondary),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Saved recipes are a member feature, so a guest never reaches this tab.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    if (!state.isMember) return;
    try {
      await state.loadSaved();
      _error = null;
    } catch (e) {
      _error = errorMessage(e);
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// A saved custom bowl reopens in the builder on its review step, so it
  /// can be checked before it is sent; a saved menu dish goes straight in.
  Future<void> _open(Bowl bowl, int index) async {
    final state = AppScope.read(context);
    if (bowl.item?.isCustomBowl ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => BowlBuilderScreen(startFrom: bowl)),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.addRecipeToCart(state.savedRecipes[index].id);
      messenger.showSnackBar(
          SnackBar(content: Text('${bowl.displayName} added to your order')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);

    // Guests never reach this screen: the Saved destination is absent from
    // their navigation. The check stays only as a guard.
    if (!state.isMember) return const SizedBox.shrink();

    if (!_loaded && state.savedBowls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && state.savedBowls.isEmpty) {
      return ErrorStateView(
        title: "We couldn't load your recipes",
        message: _error!,
        onRetry: _load,
      );
    }
    if (state.savedBowls.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bookmark_outline,
        title: 'No saved bowls yet',
        message: 'Save a bowl from the last step of the builder.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: state.savedBowls.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (context, index) {
          final bowl = state.savedBowls[index];
          return Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Reopens the builder on its review step with a copy of this
              // bowl, so the recipe can be checked and adjusted before it is
              // sent rather than going straight into the cart unseen.
              onTap: () => _open(bowl, index),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Row(
                  children: [
                    EmojiTile(
                        emoji: foodEmoji(bowl.item?.name ?? 'bowl'),
                        colour: AppColors.tileBlue,
                        size: 56),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bowl.displayName,
                            style: AppTypography.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(bowl.summary, style: AppTypography.secondary),
                        ],
                      ),
                    ),
                    Text(formatPrice(bowl.price),
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700)),
                    // One trailing control, as before. Rename and Remove live
                    // inside it rather than as two icons, which would crowd
                    // the row and push the price off its edge.
                    PopupMenuButton<String>(
                      icon:
                          Icon(Icons.more_vert, color: AppColors.textSecondary),
                      tooltip: 'More',
                      color: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCard),
                      ),
                      onSelected: (choice) => choice == 'rename'
                          ? _renameSaved(context, state, index)
                          : _removeSaved(context, state, index),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 19, color: AppColors.base),
                              const SizedBox(width: AppSpacing.md),
                              Text('Rename', style: AppTypography.body),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline,
                                  size: 19, color: AppColors.error),
                              const SizedBox(width: AppSpacing.md),
                              Text('Remove',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Confirms before dropping a saved recipe, because there is no undo and the
/// bowl took six steps to build.
Future<void> _removeSaved(
    BuildContext context, AppState state, int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Remove this recipe?'),
      content: Text('It will not affect any order you have already placed.',
          style: AppTypography.body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it')),
        ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove')),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await state.removeSavedBowl(index);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }
}

/// Renames a saved recipe in place.
Future<void> _renameSaved(
    BuildContext context, AppState state, int index) async {
  if (index < 0 || index >= state.savedBowls.length) return;
  final bowl = state.savedBowls[index];

  final name = await promptForBowlName(
    context,
    initial: bowl.name.isEmpty ? bowl.suggestedName : bowl.name,
    title: 'Rename this recipe',
  );
  if (name == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await state.renameSavedBowl(index, name);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.read(context);
      if (!state.isMember) return;
      try {
        await state.loadLoyalty();
      } catch (_) {
        // The card falls back to the points on the profile.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final state = AppScope.of(context);
    final member = state.isMember;
    final profile = state.profile;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Text(member ? (profile?.initial ?? 'M') : 'G',
                  style: AppTypography.sectionHeading),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member ? (profile?.name ?? 'Member') : 'Guest',
                      style: AppTypography.sectionHeading),
                  Text(
                      member
                          ? (profile?.email ?? 'Full access')
                          : 'Limited access',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.secondary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if (member && profile != null) _LoyaltyCard(state: state),

        // A guest has no profile record, so the app offers the upgrade
        // instead of showing account rows that would not work.
        if (!member)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.tileCream,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep your orders', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Guest orders are only kept on this device. Create an '
                  'account to keep your history, save recipes and earn points.',
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

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final loyalty = state.loyalty;
    final points = loyalty?.points ?? state.profile!.loyaltyPoints;
    final tier = loyalty?.tier ?? state.profile!.loyaltyTier;
    final next = loyalty?.nextTier;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.header,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROBOMOS POINTS',
                    style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary, letterSpacing: 1.2)),
                Text('$points',
                    style: AppTypography.screenTitle
                        .copyWith(color: Colors.white)),
                if (next != null && loyalty != null)
                  Text('${loyalty.pointsToNextTier} to ${_title(next)}',
                      style: AppTypography.secondary
                          .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text(_title(tier),
                style:
                    AppTypography.label.copyWith(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}

String _title(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Signing out clears the session and returns to the entry screen. Leaving
/// the user inside the app as a guest would be wrong: they did not choose to
/// continue as a guest, they chose to leave.
Future<void> _confirmSignOut(BuildContext context) async {
  final state = AppScope.read(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Log out?'),
      content: Text(
        'You will be returned to the start. Your cart stays with your account.',
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
  final navigator = Navigator.of(context);
  await state.signOut();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const IntroScreen()),
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
    // A Material rather than a decorated Container: the tap ripple is drawn
    // by the nearest Material above it, so an opaque box sitting on top of
    // that Material hides the ripple completely.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: AppColors.base),
          title: Text(label, style: AppTypography.body),
          trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: onTap,
        ),
      ),
    );
  }
}
