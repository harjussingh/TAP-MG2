import 'package:flutter/material.dart';

import 'api.dart';
import 'app_state.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  runApp(RoboKitchenPanel(state: AppState(ApiClient(storage: TokenStorage()))));
}

class RoboKitchenPanel extends StatefulWidget {
  const RoboKitchenPanel({super.key, required this.state, this.restoreSession = true});
  final AppState state;

  /// Tests turn this off so they start on the sign-in screen without storage.
  final bool restoreSession;

  @override
  State<RoboKitchenPanel> createState() => _RoboKitchenPanelState();
}

class _RoboKitchenPanelState extends State<RoboKitchenPanel> {
  late final Future<void> _ready = widget.restoreSession ? widget.state.restore() : Future.value();

  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        title: 'RoboKitchen · Service panel',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: FutureBuilder<void>(
          future: _ready,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const _Gate();
          },
        ),
      ),
    );
  }
}

/// Shows the sign-in screen or the panel, depending on whether someone is signed in.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return state.user == null ? const LoginScreen() : Shell(key: ValueKey(state.user!['id']));
  }
}
