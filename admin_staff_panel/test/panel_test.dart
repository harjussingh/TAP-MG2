import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:robokitchen_panel/api.dart';
import 'package:robokitchen_panel/app_state.dart';
import 'package:robokitchen_panel/format.dart';
import 'package:robokitchen_panel/main.dart';

/// A 1x1 transparent PNG, so QR images decode.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

Map<String, dynamic> _user(String role, String name) => {
      'id': 'usr_$role',
      'email': '$role@robokitchen.com',
      'full_name': name,
      'role': role,
      'is_active': true,
      'loyalty_points': 0,
      'last_login_at': '2026-10-07T04:13:46Z',
    };

Map<String, dynamic> _order(int n, String status, {String payStatus = 'unpaid', String method = 'cash'}) => {
      'id': 'ord_$n',
      'order_number': n,
      'status': status,
      'order_type': 'dine_in',
      'table': {'number': 4},
      'customer': {'name': 'Sam', 'email': 'sam@example.com', 'phone': null},
      'items': [
        {
          'name': 'Build Your Own Bowl',
          'quantity': 2,
          'line_total_cents': 2990,
          'selections': [
            {'name': 'White Rice'},
            {'name': 'Salmon'}
          ],
          'special_instructions': 'no sesame',
        }
      ],
      'pricing': {
        'subtotal_cents': 2990,
        'discount_cents': 0,
        'tax_rate': 0.1,
        'tax_cents': 299,
        'service_fee_cents': 0,
        'tip_cents': 0,
        'total_cents': 3289,
      },
      'payment': {'method': method, 'status': payStatus},
      'status_history': [
        {'status': 'confirmed', 'at': '2026-10-07T04:00:00Z'}
      ],
      'notes': null,
      'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(),
    };

/// In-memory fake of the parts of the Python API the panel uses. Records every write.
class FakeBackend {
  final calls = <String>[];
  final orders = <String, Map<String, dynamic>>{
    'ord_1001': _order(1001, 'confirmed'),
    'ord_1002': _order(1002, 'ready', payStatus: 'paid', method: 'card'),
  };
  bool acceptingOrders = true;
  final users = [_user('admin', 'Admin User'), _user('staff', 'Staff User')];

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1', '');
    final key = '${r.method} $path';
    if (r.method != 'GET') calls.add(r.body.isEmpty ? key : '$key ${r.body}');
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;

    if (key == 'GET /health') return _json({'status': 'ok', 'database': 'ok'});
    if (key == 'GET /tables/numbers') return _json([1, 2, 3]);
    if (key == 'GET /payments/config') return _json({'currency': 'aud', 'methods': ['card', 'cash']});
    if (key == 'POST /auth/login') {
      final email = body['email'] as String;
      const passwords = {
        'admin@robokitchen.com': 'Admin12345',
        'staff@robokitchen.com': 'Staff12345',
        'customer@robokitchen.com': 'Customer123',
      };
      if (passwords[email] != body['password']) return _json({'detail': 'Invalid email or password'}, 401);
      final role = email.split('@').first;
      final user = role == 'admin' ? users[0] : role == 'staff' ? users[1] : _user('customer', 'Cust');
      return _json({'access_token': 'acc-$role', 'refresh_token': 'ref-$role', 'user': user});
    }
    if (key == 'POST /auth/logout') return _json({'message': 'ok'});
    if (key == 'GET /users/me') return _json(users[0]);

    // staff
    if (key == 'GET /staff/orders') {
      final wanted = r.url.queryParametersAll['status'] ?? const [];
      final list = orders.values.where((o) => wanted.isEmpty || wanted.contains(o['status'])).toList();
      return _json({'items': list, 'total': list.length, 'page': 1, 'pages': 1});
    }
    if (key == 'GET /staff/orders/summary') {
      return _json({'confirmed': 1, 'preparing': 0, 'ready': 1, 'pending_payment': 0, 'kitchen_queue': 1, 'kitchen_failed': 1});
    }
    final orderMatch = RegExp(r'^/staff/orders/(ord_\d+)(/.*)?$').firstMatch(path);
    if (orderMatch != null) {
      final o = orders[orderMatch.group(1)]!;
      switch ((r.method, orderMatch.group(2))) {
        case ('GET', null):
          return _json(o);
        case ('PATCH', '/status'):
          o['status'] = body['status'];
          return _json(o);
        case ('POST', '/mark-paid'):
          (o['payment'] as Map)['status'] = 'paid';
          return _json(o);
        case ('POST', '/cancel'):
          o['status'] = 'cancelled';
          return _json(o);
      }
    }
    if (key == 'GET /staff/kitchen/jobs') {
      return _json([
        {'id': 'job_abcdef123456', 'order_number': 1001, 'table_number': 4, 'items': [{'name': 'Bowl', 'quantity': 2}],
          'station': 'robot-A', 'status': 'failed', 'progress': 40, 'message': 'Dispenser D03 empty'},
      ]);
    }
    if (key.startsWith('POST /staff/kitchen/jobs/') && key.endsWith('/retry')) return _json({'status': 'queued'});
    if (key == 'GET /staff/ingredients') {
      return _json([
        {'id': 'ing_1', 'name': 'Salmon', 'group': 'protein', 'is_available': true},
        {'id': 'ing_2', 'name': 'White Rice', 'group': 'base', 'is_available': true},
      ]);
    }
    if (key == 'GET /staff/menu-items') {
      return _json([
        {'id': 'itm_1', 'name': 'Build Your Own Bowl', 'category_id': 'cat_1', 'item_type': 'custom_bowl',
          'base_price_cents': 1095, 'is_available': true, 'is_featured': true, 'rating_avg': 4.5, 'rating_count': 2},
      ]);
    }
    if (r.method == 'PATCH' && path.endsWith('/availability')) return _json({'ok': true});
    if (key == 'GET /menu/categories') return _json([{'id': 'cat_1', 'name': 'Build Your Own'}]);

    // admin
    if (key == 'GET /admin/dashboard') {
      return _json({
        'orders_total': 2, 'orders_completed': 1, 'revenue_cents': 3290, 'tax_cents': 300, 'tips_cents': 0,
        'average_order_cents': 1645, 'orders_by_type': {'dine_in': 1, 'takeaway': 1},
        'top_items': [{'name': 'Build Your Own Bowl', 'quantity': 2, 'revenue_cents': 2990}],
        'average_rating': 5.0, 'new_customers': 2, 'active_orders': 1, 'kitchen_failed_jobs': 1,
      });
    }
    if (key == 'GET /admin/settings') {
      return _json({
        'restaurant_name': 'RoboKitchen', 'currency': 'aud', 'tax_rate': 0.1, 'tax_label': 'GST',
        'service_fee_cents': 0, 'is_accepting_orders': acceptingOrders, 'avg_prep_minutes': 4, 'points_per_dollar': 10,
        'point_value_cents': 1, 'min_points_to_redeem': 100, 'max_redeem_percent': 50,
      });
    }
    if (key == 'PATCH /admin/settings') {
      acceptingOrders = body['is_accepting_orders'] as bool;
      return _json(body);
    }
    if (key == 'GET /admin/orders') {
      final list = orders.values.toList();
      return _json({'items': list, 'total': list.length, 'page': 1, 'pages': 1});
    }
    if (RegExp(r'^/admin/orders/ord_\d+/refund$').hasMatch(path)) return _json({'ok': true});
    if (key == 'GET /admin/tables') {
      return _json([
        {'id': 'tbl_1', 'number': 1, 'name': 'Table 1', 'code': 'abc', 'seats': 4, 'is_active': true,
          'scan_url': 'http://localhost:3000/?table=abc'},
      ]);
    }
    if (path.endsWith('.png')) return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
    if (key == 'POST /admin/tables/tbl_1/regenerate-code') return _json({'ok': true});
    if (key == 'GET /admin/reviews') {
      return _json({'items': [
        {'id': 'rev_1', 'order_number': 1001, 'author_name': 'Sam', 'rating': 4, 'comment': 'Tasty',
          'is_visible': true, 'staff_reply': null, 'created_at': '2026-10-07T04:13:43Z'},
      ], 'total': 1, 'page': 1, 'pages': 1});
    }
    if (r.method == 'PATCH' && path.startsWith('/admin/reviews/')) return _json({'ok': true});
    if (key == 'GET /admin/users') return _json({'items': users, 'total': users.length, 'page': 1, 'pages': 1});
    if (key == 'POST /admin/users') {
      final u = {..._user(body['role'] as String, body['full_name'] as String), 'id': 'usr_new', 'email': body['email']};
      users.add(u);
      return _json(u, 201);
    }
    if (r.method == 'PATCH' && path.startsWith('/admin/users/')) return _json({'ok': true});

    return _json({'detail': 'Not handled in fake: $key'}, 404);
  }
}

late FakeBackend backend;

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  backend = FakeBackend();
  final api = ApiClient(base: 'http://test', client: MockClient(backend.handle));
  await tester.pumpWidget(RoboKitchenPanel(state: AppState(api, liveUpdates: false), restoreSession: false));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, {required bool manager, String? password}) async {
  await tester.tap(find.byKey(Key(manager ? 'choose-manager' : 'choose-staff')));
  await tester.pumpAndSettle();
  if (password != null) await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('sign-in')));
  await tester.pumpAndSettle();
}

/// Ends the test with no timers or sockets left running.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    currencyCode = 'AUD';
    taxLabel = 'GST';
  });

  test('money and time helpers', () {
    expect(money(149500), r'$1,495.00');
    expect(money(-250), r'-$2.50');
    expect(money(null), r'$0.00');
    expect(mmss(605), '10:05');
    expect(human('pay_at_counter'), 'pay at counter');
    expect(errorMessage('{"detail":[{"msg":"a"},{"msg":"b"}]}', 'x'), 'a, b');
    expect(errorMessage('not json', 'fallback'), 'fallback');
  });

  testWidgets('sign-in screen shows stations and service status', (tester) async {
    await pumpApp(tester);
    expect(find.text('Who is signing in?'), findsOneWidget);
    expect(find.text('online'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // tables in service
    await finish(tester);
  });

  testWidgets('wrong password shows the server message', (tester) async {
    await pumpApp(tester);
    await signIn(tester, manager: false, password: 'wrong123');
    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Who is signing in?'), findsNothing);
    await finish(tester);
  });

  testWidgets('staff account cannot use the manager station', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('choose-manager')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'staff@robokitchen.com');
    await tester.enterText(find.byKey(const Key('password')), 'Staff12345');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('This account is not a manager. Sign in as kitchen staff instead.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('staff: board, start cooking, take payment, cancel, robot, sold out, sign out', (tester) async {
    await pumpApp(tester);
    await signIn(tester, manager: false);

    // Order board with both tickets in the right columns.
    expect(find.byKey(const Key('view-title')), findsOneWidget);
    expect(find.text('Order board'), findsWidgets);
    expect(find.byKey(const Key('ticket-1001')), findsOneWidget);
    expect(find.byKey(const Key('ticket-1002')), findsOneWidget);
    expect(find.text('no sesame'), findsNWidgets(2)); // special instructions show on both tickets
    expect(find.text('Staff User'), findsOneWidget);

    await tester.tap(find.text('Start cooking'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('PATCH /staff/orders/ord_1001/status {"status":"preparing"}'));
    expect(find.text('Ready'), findsOneWidget); // ticket moved to the cooking column

    await tester.tap(find.text('Take payment'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /staff/orders/ord_1001/mark-paid'));

    // Details sheet -> cancel with a reason.
    await tester.tap(find.descendant(of: find.byKey(const Key('ticket-1001')), matching: find.text('Details')));
    await tester.pumpAndSettle();
    expect(find.text('Order #1001'), findsOneWidget);
    expect(find.text(r'$32.89'), findsOneWidget);
    expect(find.text('GST (10%)'), findsOneWidget);
    expect(find.byKey(const Key('sheet-refund')), findsNothing); // staff cannot refund
    await tester.tap(find.byKey(const Key('sheet-cancel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'customer left');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /staff/orders/ord_1001/cancel {"reason":"customer left"}'));
    expect(find.text('Order #1001'), findsNothing); // sheet closed

    // Robot queue: failed job can be retried.
    await tester.tap(find.byKey(const Key('nav-robot')));
    await tester.pumpAndSettle();
    expect(find.text('Dispenser D03 empty'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /staff/kitchen/jobs/job_abcdef123456/retry'));

    // Sold out: switching salmon off saves straight away.
    await tester.tap(find.byKey(const Key('nav-stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('ing-ing_1')), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('PATCH /staff/ingredients/ing_1/availability {"is_available":false}'));

    // Staff do not see manager screens.
    expect(find.byKey(const Key('nav-settings')), findsNothing);

    // Sign out returns to the station picker and ends the session on the server.
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Who is signing in?'), findsOneWidget);
    expect(backend.calls, contains('POST /auth/logout {"refresh_token":"ref-staff"}'));
    await finish(tester);
  });

  testWidgets('manager: every screen loads, refund, settings, team, reviews', (tester) async {
    await pumpApp(tester);
    await signIn(tester, manager: true);

    // Today
    expect(find.text('Takings'), findsOneWidget);
    expect(find.text(r'$32.90'), findsOneWidget);
    expect(find.text('1 robot job(s) failed. Open the order board to retry them.'), findsOneWidget);

    // Orders -> open a paid order -> refund
    await tester.tap(find.byKey(const Key('nav-orders')));
    await tester.pumpAndSettle();
    expect(find.text('2 order(s) · page 1 of 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Open').last);
    await tester.pumpAndSettle();
    expect(find.text('Order #1002'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sheet-refund')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cold food');
    await tester.tap(find.widgetWithText(FilledButton, 'Refund'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /admin/orders/ord_1002/refund {"reason":"cold food"}'));

    // Board, menu, tables load
    for (final v in ['board', 'menu', 'tables']) {
      await tester.tap(find.byKey(Key('nav-$v')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'screen $v threw');
    }
    expect(find.text('One QR for the whole venue'), findsOneWidget);
    await tester.tap(find.text('Regenerate code'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /admin/tables/tbl_1/regenerate-code'));

    // Reviews: reply
    await tester.tap(find.byKey(const Key('nav-reviews')));
    await tester.pumpAndSettle();
    expect(find.text('Tasty'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Thanks Sam!');
    await tester.tap(find.text('Save reply'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('PATCH /admin/reviews/rev_1 {"staff_reply":"Thanks Sam!"}'));

    // Team: validation, then create a cook
    await tester.tap(find.byKey(const Key('nav-team')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tm-create')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tm-name')), 'New Cook');
    await tester.enterText(find.byKey(const Key('tm-email')), 'cook@robokitchen.com');
    await tester.enterText(find.byKey(const Key('tm-password')), 'Cook12345');
    await tester.tap(find.byKey(const Key('tm-create')));
    await tester.pumpAndSettle();
    expect(backend.calls.any((c) => c.startsWith('POST /admin/users') && c.contains('cook@robokitchen.com')), isTrue);
    expect(find.text('New Cook'), findsOneWidget);
    expect(find.text('you'), findsOneWidget); // cannot deactivate yourself

    // Settings: pause ordering and save
    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-open')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-settings')));
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pumpAndSettle();
    expect(backend.acceptingOrders, isFalse);
    expect(find.text('Ordering is paused'), findsOneWidget);

    // Bad input is caught before it reaches the server.
    await tester.enterText(find.byKey(const Key('set-tax_rate')), '75');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Between 0 and 50'), findsOneWidget);

    // Sign out from the rail icon as well
    await tester.tap(find.byKey(const Key('rail-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Who is signing in?'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('phone-sized screen has no layout overflow', (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(400, 860);
    await tester.pumpAndSettle();
    await signIn(tester, manager: true);
    for (final v in ['overview', 'orders', 'board', 'menu', 'tables', 'reviews', 'team', 'settings']) {
      await tester.tap(find.byKey(Key('nav-$v')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'screen $v overflowed on a phone');
    }
    await finish(tester);
  });
}
