import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomos_app/app_state.dart';
import 'package:robomos_app/models/dish.dart';
import 'package:robomos_app/models/order.dart';
import 'package:robomos_app/screens/account_detail_screens.dart';
import 'package:robomos_app/screens/account_screens.dart';
import 'package:robomos_app/screens/appearance_screen.dart';
import 'package:robomos_app/screens/auth_screen.dart';
import 'package:robomos_app/screens/bowl_builder_screen.dart';
import 'package:robomos_app/screens/cart_screen.dart';
import 'package:robomos_app/screens/checkout_screen.dart';
import 'package:robomos_app/screens/continue_as_screen.dart';
import 'package:robomos_app/screens/dish_detail_screen.dart';
import 'package:robomos_app/screens/edit_details_screen.dart';
import 'package:robomos_app/screens/forgot_password_screen.dart';
import 'package:robomos_app/screens/home_shell.dart';
import 'package:robomos_app/screens/language_screen.dart';
import 'package:robomos_app/screens/menu_screen.dart';
import 'package:robomos_app/screens/notification_settings_screen.dart';
import 'package:robomos_app/screens/order_confirmed_screen.dart';
import 'package:robomos_app/screens/order_tracking_screen.dart';
import 'package:robomos_app/screens/qr_screen.dart';
import 'package:robomos_app/screens/reset_password_screen.dart';
import 'package:robomos_app/screens/review_screen.dart';
import 'package:robomos_app/screens/settings_screen.dart';
import 'package:robomos_app/screens/table_number_screen.dart';
import 'package:robomos_app/theme/app_settings.dart';
import 'package:robomos_app/theme/app_theme.dart';

import 'helpers/fake_backend.dart';
import 'helpers/real_fonts.dart';

/// A signed-in member at table 7 who has placed one order (now ready, so it
/// can be reviewed) and has another item in the cart. Built through the same
/// API calls the screens make.
Future<(AppState, List<Dish>)> memberState(Map<String, Object> prefs) async {
  final (s, backend) = await fakeAppState(prefs: prefs);
  await s.login(FakeBackend.customerEmail, FakeBackend.customerPassword);
  await s.chooseTable(7);
  await s.addToCart('itm_teriyaki');
  await s.addToCart('itm_tofu');
  final order = await s.checkout(method: PaymentMethod.cash);
  backend.advance(order.id, 'ready');
  await s.refreshOrder(order.id);
  await s.addToCart('itm_miso', quantity: 2);
  await s.loadHistory();
  return (s, await s.loadMenu());
}

/// Same wrapping as RobomosApp: app state above, settings scope around every route.
Future<void> show(WidgetTester tester, Widget screen, AppState state,
    AppSettings settings) async {
  await tester.pumpWidget(AppScope(
    notifier: state,
    child: MaterialApp(
      theme: AppTheme.build(),
      builder: (context, child) => SettingsScope(
          notifier: settings, child: child ?? const SizedBox.shrink()),
      home: screen,
    ),
  ));
  // Lets each screen's own loading calls finish and their animations run.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRealFonts);

  Dish dish(List<Dish> menu, String id) => menu.firstWhere((d) => d.id == id);

  final screens = <String, Widget Function(AppState s, List<Dish> menu)>{
    'QrScreen': (_, __) => const QrScreen(),
    'ContinueAsScreen': (_, __) => const ContinueAsScreen(),
    'AuthScreen': (_, __) => const AuthScreen(),
    'AuthScreen (sign up)': (_, __) => const AuthScreen(mode: AuthMode.signUp),
    'ForgotPasswordScreen': (_, __) =>
        const ForgotPasswordScreen(email: 'sam@example.com'),
    'ResetPasswordScreen': (_, __) =>
        const ResetPasswordScreen(token: 'test-token'),
    'TableNumberScreen': (_, __) => const TableNumberScreen(),
    'HomeShell (member)': (_, __) => const HomeShell(),
    // The menu is always shown inside the home shell's Scaffold.
    'MenuScreen': (_, __) => const Scaffold(body: MenuScreen()),
    'DishDetailScreen': (_, m) =>
        DishDetailScreen(dish: dish(m, 'itm_teriyaki')),
    'DishDetailScreen (sold out)': (_, m) =>
        DishDetailScreen(dish: dish(m, 'itm_salmon')),
    'DishDetailScreen (custom)': (_, m) =>
        DishDetailScreen(dish: dish(m, 'itm_byo')),
    'BowlBuilderScreen': (_, m) =>
        BowlBuilderScreen(item: dish(m, 'itm_byo').item),
    'CartScreen': (_, __) => const CartScreen(),
    'CheckoutScreen': (_, __) => const CheckoutScreen(),
    'OrderConfirmedScreen': (s, _) =>
        OrderConfirmedScreen(order: s.activeOrder!),
    'OrderTrackingScreen': (s, _) => OrderTrackingScreen(order: s.activeOrder!),
    'ReviewScreen': (s, _) => ReviewScreen(order: s.activeOrder!),
    'HistoryScreen': (_, __) => const Scaffold(body: HistoryScreen()),
    'SavedScreen': (_, __) => const Scaffold(body: SavedScreen()),
    'ProfileScreen': (_, __) => const Scaffold(body: ProfileScreen()),
    'EditDetailsScreen': (_, __) => const EditDetailsScreen(),
    'SettingsScreen': (_, __) => const SettingsScreen(),
    'AppearanceScreen': (_, __) => const AppearanceScreen(),
    'LanguageScreen': (_, __) => const LanguageScreen(),
    'NotificationSettingsScreen': (_, __) => const NotificationSettingsScreen(),
    'DietaryPreferencesScreen': (_, __) => const DietaryPreferencesScreen(),
    'NotificationsScreen': (_, __) => const NotificationsScreen(),
  };

  // Phone size, and saved preferences (ap_text 3 = "Extra large" text, ap_dark = dark mode).
  const configs = <(String, Size, Map<String, Object>)>[
    ('360x740 phone', Size(360, 740), {}),
    ('412x915 phone', Size(412, 915), {}),
    (
      '360x740 phone, extra large text, dark',
      Size(360, 740),
      {'ap_text': 3, 'ap_dark': true}
    ),
  ];

  for (final (label, size, prefs) in configs) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders on a $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final (state, menu) = await memberState(prefs);
        final settings = await AppSettings.open();
        installSettings(settings);

        await show(tester, entry.value(state, menu), state, settings);
        expect(tester.takeException(), isNull);

        // End cleanly so timers (countdowns, polls, animations) don't leak
        // into the next test.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }

  testWidgets('a guest home has no Saved tab', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (state, _) = await fakeAppState();
    final settings = await AppSettings.open();
    installSettings(settings);
    state.setRole(UserRole.guest);
    await show(tester, const HomeShell(), state, settings);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the menu shows an error with a retry when the server is down',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (state, backend) = await fakeAppState();
    final settings = await AppSettings.open();
    installSettings(settings);
    backend.failEverything = true;
    await show(tester, const Scaffold(body: MenuScreen()), state, settings);
    expect(find.text("We couldn't load the menu"), findsOneWidget);

    backend.failEverything = false;
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Teriyaki Chicken Bowl'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
