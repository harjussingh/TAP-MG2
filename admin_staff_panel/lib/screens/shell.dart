import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'board_view.dart';
import 'manager_views.dart';
import 'staff_views.dart';

class ViewDef {
  const ViewDef(this.key, this.label, this.icon, {this.live = false});
  final String key, label;
  final IconData icon;

  /// Live views reload on socket events and every 15 seconds.
  final bool live;
}

const staffViews = [
  ViewDef('board', 'Order board', Icons.view_agenda_outlined, live: true),
  ViewDef('robot', 'Robot queue', Icons.precision_manufacturing_outlined, live: true),
  ViewDef('stock', 'Sold out', Icons.inventory_2_outlined),
];

const managerViews = [
  ViewDef('overview', 'Today', Icons.insights_outlined, live: true),
  ViewDef('orders', 'Orders', Icons.receipt_long_outlined, live: true),
  ViewDef('board', 'Order board', Icons.view_agenda_outlined, live: true),
  ViewDef('menu', 'Menu', Icons.restaurant_menu_outlined),
  ViewDef('tables', 'Tables & QR', Icons.qr_code_2_outlined),
  ViewDef('reviews', 'Reviews', Icons.star_border_rounded),
  ViewDef('team', 'Team', Icons.group_outlined),
  ViewDef('settings', 'Settings', Icons.tune_outlined),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late String _current;
  final _manual = ValueNotifier<int>(0);
  final _timerTick = ValueNotifier<int>(0);
  Timer? _timer;
  StreamSubscription<String>? _announce;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _current = (state.isManager ? managerViews : staffViews).first.key;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _timerTick.value++);
    _announce = state.announcements.listen((m) {
      if (mounted) toast(context, m);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _announce?.cancel();
    _manual.dispose();
    _timerTick.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    await AppScope.read(context).signOut();
  }

  Widget _view(ViewDef v, AppState state) {
    final refresh = v.live ? Listenable.merge([_manual, _timerTick, state.liveSignal]) : _manual;
    return switch (v.key) {
      'board' => BoardView(refresh: refresh),
      'robot' => RobotView(refresh: refresh),
      'stock' => StockView(refresh: refresh),
      'overview' => OverviewView(refresh: refresh),
      'orders' => OrdersView(refresh: refresh),
      'menu' => MenuView(refresh: refresh),
      'tables' => TablesView(refresh: refresh),
      'reviews' => ReviewsView(refresh: refresh),
      'team' => TeamView(refresh: refresh),
      'settings' => SettingsView(refresh: refresh),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final views = state.isManager ? managerViews : staffViews;
    final current = views.firstWhere((v) => v.key == _current, orElse: () => views.first);
    final narrow = MediaQuery.sizeOf(context).width < 820;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Rail(
              views: views,
              current: current.key,
              compact: narrow,
              onSelect: (k) => setState(() => _current = k),
              onSignOut: _signOut,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    title: current.label,
                    state: state,
                    narrow: narrow,
                    signingOut: _signingOut,
                    onRefresh: () => _manual.value++,
                    onSignOut: _signOut,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(narrow ? 12 : 20),
                      // Keyed by view so switching screens starts a fresh load.
                      child: KeyedSubtree(key: ValueKey(current.key), child: _view(current, state)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.views, required this.current, required this.compact, required this.onSelect,
      required this.onSignOut});
  final List<ViewDef> views;
  final String current;
  final bool compact;
  final ValueChanged<String> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final w = compact ? 52.0 : 64.0;
    return Container(
      width: w,
      decoration: const BoxDecoration(color: RK.rail, border: Border(right: BorderSide(color: RK.line))),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: RK.surface2, border: Border.all(color: RK.line), borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.center,
            child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: RK.cooking, shape: BoxShape.circle)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                for (final v in views)
                  _RailButton(
                    key: Key('nav-${v.key}'),
                    icon: v.icon,
                    label: v.label,
                    selected: v.key == current,
                    width: w,
                    onTap: () => onSelect(v.key),
                  ),
              ]),
            ),
          ),
          _RailButton(
            key: const Key('rail-sign-out'),
            icon: Icons.logout,
            label: 'Sign out',
            selected: false,
            width: w,
            onTap: onSignOut,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({super.key, required this.icon, required this.label, required this.selected, required this.width,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: width,
            height: 46,
            decoration: BoxDecoration(
              color: selected ? RK.cooking.withValues(alpha: 0.08) : null,
              border: Border(left: BorderSide(color: selected ? RK.cooking : Colors.transparent, width: 2)),
            ),
            child: Icon(icon, size: 20, color: selected ? RK.cooking : RK.dim),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.state, required this.narrow, required this.signingOut,
      required this.onRefresh, required this.onSignOut});
  final String title;
  final AppState state;
  final bool narrow, signingOut;
  final VoidCallback onRefresh, onSignOut;

  @override
  Widget build(BuildContext context) {
    final (dot, text) = switch (state.live) {
      LiveState.live => (RK.ready, 'live'),
      LiveState.connecting => (RK.dim, 'connecting'),
      LiveState.offline => (RK.alert, 'reconnecting'),
    };
    final user = state.user ?? const {};
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 22, vertical: 12),
      decoration: const BoxDecoration(color: RK.rail, border: Border(bottom: BorderSide(color: RK.line))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(title, key: const Key('view-title'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(text, key: const Key('live-state'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
              _Pill(children: [
                Text('${user['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(' · ${state.isManager ? 'manager' : 'kitchen'}', style: const TextStyle(color: RK.muted, fontSize: 12)),
              ]),
              OutlinedButton(key: const Key('refresh'), onPressed: onRefresh, child: const Text('Refresh')),
              OutlinedButton.icon(
                key: const Key('sign-out'),
                onPressed: signingOut ? null : onSignOut,
                icon: const Icon(Icons.logout, size: 16),
                label: Text(signingOut ? 'Signing out…' : 'Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: RK.line), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );
}
