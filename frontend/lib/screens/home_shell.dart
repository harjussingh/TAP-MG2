import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import 'account_screens.dart';
import 'menu_screen.dart';

/// Navigation is built from the role.
///
/// A guest does not get a Saved tab that tells them saved bowls are for
/// members. The destination is simply not there, so each role gets a smaller
/// app rather than a locked one.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final member = AppScope.of(context).isMember;
    return _Shell(key: ValueKey(member), isMember: member);
  }
}

class _Shell extends StatefulWidget {
  const _Shell({super.key, required this.isMember});

  final bool isMember;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final pages = <Widget>[
      // Deliberately not const: a const widget is skipped on rebuild, so the
      // tabs would keep the old palette after a theme change.
      MenuScreen(),
      SafeArea(child: HistoryScreen()),
      if (widget.isMember) SafeArea(child: SavedScreen()),
      SafeArea(child: ProfileScreen()),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.restaurant_menu_outlined),
        selectedIcon: Icon(Icons.restaurant_menu),
        label: 'Order',
      ),
      const NavigationDestination(
        icon: Icon(Icons.access_time),
        selectedIcon: Icon(Icons.history),
        label: 'History',
      ),
      if (widget.isMember)
        const NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Saved',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    // Keeps the index valid if the role changes while a later tab is open.
    final index = _index.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => _index = v),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primary,
        destinations: destinations,
      ),
    );
  }
}
