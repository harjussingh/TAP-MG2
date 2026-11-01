import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/intro_screen.dart';
import 'screens/reset_password_screen.dart';
import 'theme/app_settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences have to be loaded before the first frame, or the app would
  // flash the default theme before switching to the person's own.
  final appSettings = await AppSettings.open();
  installSettings(appSettings);

  final state = await AppState.create();

  // On the web the app is opened from links: a table's QR code points at
  // FRONTEND_URL/?table=CODE and the reset email at /reset-password?token=...
  Widget? home;
  if (kIsWeb) {
    final link = Uri.base;
    final table = link.queryParameters['table'];
    if (table != null && table.isNotEmpty) state.pendingTableCode = table;
    final token = link.queryParameters['token'];
    if (link.path.contains('reset-password') &&
        token != null &&
        token.isNotEmpty) {
      home = ResetPasswordScreen(token: token);
    }
  }

  runApp(RobomosApp(settings: appSettings, state: state, home: home));
}

class RobomosApp extends StatefulWidget {
  const RobomosApp({
    super.key,
    required this.settings,
    required this.state,
    this.home,
    this.restoreSession = true,
  });

  final AppSettings settings;
  final AppState state;

  /// The first screen. Defaults to the intro.
  final Widget? home;

  /// Signs a returning member back in with their saved tokens.
  final bool restoreSession;

  @override
  State<RobomosApp> createState() => _RobomosAppState();
}

class _RobomosAppState extends State<RobomosApp> {
  @override
  void initState() {
    super.initState();
    if (widget.restoreSession) widget.state.restoreSession();
  }

  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listening here rebuilds the whole tree when a setting changes, which is
    // what lets the colour tokens be plain getters: every screen re-reads them.
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) => AppScope(
        notifier: widget.state,
        child: MaterialApp(
          title: 'Robomos Poke',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          // builder wraps the Navigator, so every pushed route sits below
          // this scope and can depend on it.
          builder: (context, child) => SettingsScope(
            notifier: widget.settings,
            child: child ?? const SizedBox.shrink(),
          ),
          home: widget.home ?? const IntroScreen(),
        ),
      ),
    );
  }
}
