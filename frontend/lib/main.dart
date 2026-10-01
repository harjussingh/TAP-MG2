import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/qr_screen.dart';
import 'theme/app_settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences have to be loaded before the first frame, or the app would
  // flash the default theme before switching to the person's own.
  final appSettings = await AppSettings.open();
  installSettings(appSettings);

  runApp(RobomosApp(settings: appSettings));
}

class RobomosApp extends StatefulWidget {
  const RobomosApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<RobomosApp> createState() => _RobomosAppState();
}

class _RobomosAppState extends State<RobomosApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listening here rebuilds the whole tree when a setting changes, which is
    // what lets the colour tokens be plain getters: every screen re-reads them.
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) => AppScope(
        notifier: _state,
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
          home: const QrScreen(),
        ),
      ),
    );
  }
}
