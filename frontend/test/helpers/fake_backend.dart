import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:robomos_app/app_state.dart';
import 'package:robomos_app/services/api_client.dart';
import 'package:robomos_app/services/robokitchen_api.dart';
import 'package:robomos_app/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory stand-in for the FastAPI backend, speaking the same JSON.
///
/// It mirrors the rules the screens depend on: prices worked out on the
/// server, option-group min/max checks, sold-out items, guest carts keyed by
/// X-Session-Id, guest order tokens, and the order status flow. The app talks
/// to it through the real ApiClient, so headers, errors and token handling
/// are exercised too.
class FakeBackend {
  FakeBackend() {
    _seed();
  }

  static const customerEmail = 'customer@robokitchen.com';
  static const customerPassword = 'Customer123';
  static const resetToken = 'good-reset-token';

  /// "METHOD /path" for every request, newest last.
  final List<String> calls = [];

  final Map<String, Map<String, dynamic>> _ingredients = {};
  final List<Map<String, dynamic>> _items = [];
  final Map<String, Map<String, dynamic>> _users = {};
  final Map<String, String> _passwords = {};
  final Map<String, String> _accessTokens = {};
  final Map<String, Map<String, dynamic>> _carts = {};
  final Map<String, Map<String, dynamic>> _orders = {};
  final Map<String, String> _orderTokens = {};
  final Map<String, Map<String, dynamic>> _recipes = {};
  int _seq = 0;
  int _orderNumber = 1000;

  /// When true every request fails as if the server were unreachable.
  bool failEverything = false;

  MockClient get client => MockClient(_handle);

  // ------------------------------------------------------------------ data

  void _seed() {
    void ing(String id, String name, int price, int cal,
            {bool available = true}) =>
        _ingredients[id] = {
          'id': id,
          'name': name,
          'price_cents': price,
          'calories': cal,
          'allergens': <String>[],
          'dietary_tags': <String>[],
          'is_available': available,
        };
    ing('ing_white', 'White Rice', 0, 200);
    ing('ing_brown', 'Brown Rice', 0, 215);
    ing('ing_quinoa', 'Quinoa', 100, 180);
    ing('ing_chicken', 'Grilled Chicken', 0, 180);
    ing('ing_salmon', 'Salmon', 250, 210);
    ing('ing_tofu', 'Crispy Tofu', 0, 150);
    ing('ing_prawn', 'Prawn', 300, 120, available: false);
    ing('ing_corn', 'Sweet Corn', 0, 60);
    ing('ing_avocado', 'Avocado', 150, 120);
    ing('ing_cucumber', 'Cucumber', 0, 8);
    ing('ing_teriyaki', 'Teriyaki Sauce', 0, 60);
    ing('ing_sriracha', 'Sriracha Mayo', 0, 90);
    ing('ing_sesame', 'Sesame Seeds', 0, 50);
    ing('ing_egg', 'Soft Egg', 100, 70);

    Map<String, dynamic> group(
            String key, String name, int lo, int hi, List<String> ids,
            [List<String> defaults = const []]) =>
        {
          'key': key,
          'name': name,
          'min_select': lo,
          'max_select': hi,
          'options': [
            for (final id in ids)
              {'ingredient_id': id, 'is_default': defaults.contains(id)},
          ],
        };

    Map<String, dynamic> item(String id, String name, int price,
            {String type = 'standard',
            String category = 'cat_bowls',
            String desc = '',
            List<String> tags = const [],
            List<String> dietary = const [],
            List<String> allergens = const [],
            int calories = 0,
            bool available = true,
            bool featured = false,
            List<Map<String, dynamic>> groups = const []}) =>
        {
          'id': id,
          'name': name,
          'slug': id,
          'description': desc,
          'category_id': category,
          'item_type': type,
          'base_price_cents': price,
          'tags': tags,
          'dietary_tags': dietary,
          'allergens': allergens,
          'calories': calories,
          'is_available': available,
          'is_featured': featured,
          'rating_count': 0,
          'option_groups': groups,
        };

    _items.addAll([
      item('itm_byo', 'Build Your Own Bowl', 1095,
          type: 'custom_bowl',
          category: 'cat_byo',
          desc: 'Pick a base, protein, veggies, sauce and toppings.',
          tags: ['custom'],
          featured: true,
          groups: [
            group('base', 'Choose your base', 1, 2,
                ['ing_white', 'ing_brown', 'ing_quinoa']),
            group('protein', 'Choose your protein', 1, 2,
                ['ing_chicken', 'ing_salmon', 'ing_tofu', 'ing_prawn']),
            group('veggies', 'Add veggies', 0, 5,
                ['ing_corn', 'ing_avocado', 'ing_cucumber']),
            group('sauce', 'Pick a sauce', 1, 2,
                ['ing_teriyaki', 'ing_sriracha']),
            group('topping', 'Toppings', 0, 3, ['ing_sesame']),
          ]),
      item('itm_teriyaki', 'Teriyaki Chicken Bowl', 1295,
          desc: 'Grilled chicken, rice, edamame, corn and teriyaki glaze.',
          tags: ['bestseller'],
          featured: true,
          allergens: ['soy', 'gluten'],
          calories: 580,
          groups: [
            group('base', 'Base', 1, 1,
                ['ing_white', 'ing_brown', 'ing_quinoa'], ['ing_white']),
            group('extras', 'Extras', 0, 3, ['ing_avocado', 'ing_egg']),
          ]),
      item('itm_salmon', 'Spicy Salmon Poke', 1595,
          desc: 'Salmon, cucumber, avocado and sriracha mayo.',
          tags: ['spicy'],
          allergens: ['fish', 'egg'],
          calories: 620,
          available: false),
      item('itm_tofu', 'Tofu Power Bowl', 1195,
          desc: 'Crispy tofu, quinoa, greens and peanut sauce.',
          dietary: ['vegan'],
          allergens: ['soy', 'peanut'],
          calories: 540),
      item('itm_miso', 'Miso Soup', 395,
          category: 'cat_sides',
          desc: 'Classic miso with tofu and seaweed.',
          calories: 80),
    ]);

    _users['usr_customer'] = {
      'id': 'usr_customer',
      'email': customerEmail,
      'full_name': 'Demo Customer',
      'phone': null,
      'role': 'customer',
      'email_verified': true,
      'dietary_preferences': <String>[],
      'allergens': <String>[],
      'marketing_opt_in': false,
      'loyalty_points': 250,
      'lifetime_points': 250,
      'loyalty_tier': 'bronze',
    };
    _passwords[customerEmail] = customerPassword;
  }

  /// Moves an order on, as the kitchen or the staff panel would.
  void advance(String orderId, String status) {
    final order = _orders[orderId]!;
    order['status'] = status;
    (order['status_history'] as List).add({'status': status, 'at': _now()});
    if (status == 'completed') {
      order['payment']['status'] = 'paid';
    }
  }

  /// The id of the newest order.
  String get lastOrderId => _orders.keys.last;

  Map<String, dynamic> order(String id) => _orders[id]!;

  void setItemAvailable(String id, bool available) =>
      _items.firstWhere((i) => i['id'] == id)['is_available'] = available;

  // --------------------------------------------------------------- routing

  Future<http.Response> _handle(http.Request request) async {
    final uri = request.url;
    final path = uri.path.replaceFirst('/api/v1', '');
    calls.add('${request.method} $path');
    if (failEverything) throw http.ClientException('Connection refused', uri);
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final user = _userFor(request);
    final owner = user != null
        ? 'user:${user['id']}'
        : 'session:${request.headers['X-Session-Id'] ?? request.headers['x-session-id']}';

    try {
      final seg = path.split('/').where((s) => s.isNotEmpty).toList();
      switch ((request.method, seg)) {
        // ------------------------------------------------------------ auth
        case ('POST', ['auth', 'login']):
          final email = (body['email'] as String).toLowerCase();
          if (_passwords[email] != body['password']) {
            return _error(401, 'Invalid email or password');
          }
          return _json(
              _issue(_users.values.firstWhere((u) => u['email'] == email)));
        case ('POST', ['auth', 'register']):
          final email = (body['email'] as String).toLowerCase();
          if (_passwords.containsKey(email)) {
            return _error(409, 'An account with this email already exists');
          }
          final id = _id('usr');
          _users[id] = {
            ..._users['usr_customer']!,
            'id': id,
            'email': email,
            'full_name': body['full_name'],
            'loyalty_points': 0,
            'lifetime_points': 0,
          };
          _passwords[email] = body['password'] as String;
          return _json(_issue(_users[id]!), 201);
        case ('POST', ['auth', 'logout']):
          return _json({'message': 'Logged out'});
        case ('POST', ['auth', 'refresh']):
          return _error(401, 'Refresh token is no longer valid');
        case ('GET', ['auth', 'me']) || ('GET', ['users', 'me']):
          if (user == null) return _error(401, 'Not authenticated');
          return _json(_userOut(user));
        case ('PATCH', ['users', 'me']):
          if (user == null) return _error(401, 'Not authenticated');
          final map = body as Map<String, dynamic>;
          if (map.containsKey('full_name')) {
            user['full_name'] = map['full_name'];
          }
          if (map.containsKey('phone')) user['phone'] = map['phone'];
          if (map.containsKey('dietary_preferences')) {
            user['dietary_preferences'] = map['dietary_preferences'];
          }
          if (map.containsKey('allergens')) {
            user['allergens'] = map['allergens'];
          }
          if (map.containsKey('marketing_opt_in')) {
            user['marketing_opt_in'] = map['marketing_opt_in'];
          }
          return _json(_userOut(user));
        case ('POST', ['auth', 'forgot-password']):
          return _json({
            'message':
                'If an account exists for this email, a reset link has been sent'
          });
        case ('POST', ['auth', 'reset-password']):
          if (body['token'] != resetToken) {
            return _error(400, 'This link is invalid or has expired');
          }
          return _json({'message': 'Password updated. Please log in.'});

        // ------------------------------------------------------------ menu
        case ('GET', ['menu', 'categories']):
          return _json([
            {
              'id': 'cat_byo',
              'name': 'Build Your Own',
              'slug': 'build-your-own'
            },
            {'id': 'cat_bowls', 'name': 'Bowls', 'slug': 'bowls'},
            {'id': 'cat_sides', 'name': 'Sides', 'slug': 'sides'},
          ]);
        case ('GET', ['menu', 'items']):
          final all = uri.queryParameters['include_unavailable'] == 'true';
          final list = [
            for (final i in _items)
              if (all || i['is_available'] == true) _itemOut(i),
          ];
          return _json({
            'items': list,
            'total': list.length,
            'page': 1,
            'size': 100,
            'pages': 1
          });
        case ('GET', ['menu', 'items', final id]):
          final item = _items.where((i) => i['id'] == id || i['slug'] == id);
          if (item.isEmpty) return _error(404, 'Menu item not found');
          return _json(_itemOut(item.first));
        case ('POST', ['menu', 'price-quote']):
          return _json(_price(body['menu_item_id'] as String,
              body['selections'] as List, body['quantity'] as int? ?? 1));

        // ------------------------------------------------------------ cart
        case ('GET', ['cart']):
          return _json(_cartOut(_cart(owner)));
        case ('POST', ['cart', 'items']):
          final cart = _cart(owner);
          final line = _price(
              body['menu_item_id'] as String,
              body['selections'] as List? ?? const [],
              body['quantity'] as int? ?? 1);
          line['line_id'] = _id('line');
          line['raw_selections'] = body['selections'] ?? const [];
          (cart['items'] as List).add(line);
          return _json(_cartOut(cart), 201);
        case ('PATCH', ['cart', 'items', final lineId]):
          final cart = _cart(owner);
          final line = _line(cart, lineId);
          if (line == null) return _error(404, 'Cart item not found');
          final qty = body['quantity'] as int;
          line['quantity'] = qty;
          line['line_total_cents'] = (line['unit_price_cents'] as int) * qty;
          return _json(_cartOut(cart));
        case ('DELETE', ['cart', 'items', final lineId]):
          final cart = _cart(owner);
          (cart['items'] as List).removeWhere((l) => l['line_id'] == lineId);
          return _json(_cartOut(cart));
        case ('DELETE', ['cart']):
          final cart = _cart(owner);
          (cart['items'] as List).clear();
          return _json(_cartOut(cart));
        case ('PUT', ['cart', 'context']):
          final cart = _cart(owner);
          final number = body['table_number'] as int?;
          final code = body['table_code'] as String?;
          if (number != null || code != null) {
            final n = number ?? int.tryParse(code!.replaceFirst('code-', ''));
            if (n == null || n < 1 || n > 10) {
              return _error(404,
                  'Table not found. Please check the number on your table.');
            }
            cart['table'] = {'id': 'tbl_$n', 'number': n, 'name': 'Table $n'};
          } else {
            cart['table'] = null;
          }
          cart['order_type'] = body['order_type'];
          return _json(_cartOut(cart));
        case ('POST', ['cart', 'merge']):
          if (user == null) return _error(401, 'Not authenticated');
          final mine = _cart(owner);
          final guest = _carts.remove(
              'session:${request.headers['X-Session-Id'] ?? request.headers['x-session-id']}');
          if (guest != null) {
            (mine['items'] as List).addAll(guest['items'] as List);
            if (mine['table'] == null && guest['table'] != null) {
              mine['table'] = guest['table'];
              mine['order_type'] = guest['order_type'];
            }
          }
          return _json(_cartOut(mine));

        // ---------------------------------------------------------- orders
        case ('POST', ['orders', 'checkout']):
          final cart = _cart(owner);
          if ((cart['items'] as List).isEmpty) {
            return _error(400, 'Your cart is empty');
          }
          if (user == null &&
              ((body['customer_name'] as String?) ?? '').trim().isEmpty) {
            return _error(422, 'customer_name is required for guest checkout');
          }
          final redeem = body['redeem_points'] as int? ?? 0;
          final isCard = body['payment_method'] == 'card';
          final id = _id('ord');
          final totals = _totals(cart, redeem: user == null ? 0 : redeem);
          if (user != null && redeem > 0) {
            user['loyalty_points'] = (user['loyalty_points'] as int) -
                (totals['points_redeemed'] as int);
          }
          final order = <String, dynamic>{
            'id': id,
            'order_number': ++_orderNumber,
            'status': isCard ? 'pending_payment' : 'confirmed',
            'order_type': cart['order_type'],
            'table': cart['table'],
            'user_id': user?['id'],
            'customer': {'name': body['customer_name'] ?? user?['full_name']},
            'items': [
              for (final l in cart['items'] as List)
                Map<String, dynamic>.from(l as Map)
            ],
            'pricing': totals,
            'currency': 'aud',
            'payment': {
              'method': body['payment_method'],
              'status': isCard ? 'pending' : 'unpaid'
            },
            'status_history': [
              {'status': isCard ? 'pending_payment' : 'confirmed', 'at': _now()}
            ],
            'estimated_ready_at': isCard ? null : _inMinutes(5),
            'points_earned': 0,
            'has_review': false,
            'created_at': _now(),
            'updated_at': _now(),
          };
          _orders[id] = order;
          final token = 'order-token-$id';
          _orderTokens[id] = token;
          (cart['items'] as List).clear();
          return _json({
            'order': order,
            'order_access_token': token,
            'payment': {
              'provider': isCard ? 'mock' : 'offline',
              'requires_action': isCard
            },
          }, 201);
        case ('GET', ['orders', 'me']):
          if (user == null) return _error(401, 'Not authenticated');
          final mine = _orders.values
              .where((o) => o['user_id'] == user['id'])
              .toList()
              .reversed
              .toList();
          return _json({
            'items': mine,
            'total': mine.length,
            'page': 1,
            'size': 50,
            'pages': 1
          });
        case ('GET', ['orders', final id]):
          final order = _viewable(id, user, request);
          if (order == null) return _error(404, 'Order not found');
          return _json(order);
        case ('POST', ['orders', final id, 'cancel']):
          final order = _viewable(id, user, request);
          if (order == null) return _error(404, 'Order not found');
          if (!['pending_payment', 'confirmed'].contains(order['status'])) {
            return _error(409, 'This order can no longer be cancelled');
          }
          order['status'] = 'cancelled';
          order['cancel_reason'] = body?['reason'];
          return _json(order);
        case ('POST', ['orders', final id, 'reorder']):
          final order = _viewable(id, user, request);
          if (order == null) return _error(404, 'Order not found');
          final cart = _cart(owner);
          for (final l in order['items'] as List) {
            (cart['items'] as List)
                .add({...(l as Map<String, dynamic>), 'line_id': _id('line')});
          }
          return _json({
            'added': (order['items'] as List).length,
            'skipped': <String>[]
          });
        case ('POST', ['payments', final id, 'mock-confirm']):
          final order = _viewable(id, user, request);
          if (order == null) return _error(404, 'Order not found');
          order['status'] = 'confirmed';
          order['payment']['status'] = 'paid';
          order['estimated_ready_at'] = _inMinutes(5);
          return _json(order);

        // --------------------------------------------- reviews and recipes
        case ('POST', ['reviews']):
          final order = _viewable(body['order_id'] as String, user, request);
          if (order == null) return _error(404, 'Order not found');
          if (!['ready', 'completed'].contains(order['status'])) {
            return _error(409, 'You can review an order once it is ready');
          }
          if (order['has_review'] == true) {
            return _error(409, 'This order has already been reviewed');
          }
          order['has_review'] = true;
          return _json({
            'id': _id('rev'),
            'order_id': order['id'],
            'rating': body['rating']
          }, 201);
        case ('GET', ['recipes']):
          if (user == null) return _error(401, 'Not authenticated');
          return _json(_recipes.values
              .where((r) => r['user_id'] == user['id'])
              .toList());
        case ('POST', ['recipes']):
          if (user == null) return _error(401, 'Not authenticated');
          final priced = _price(
              body['menu_item_id'] as String, body['selections'] as List, 1);
          final id = _id('rcp');
          _recipes[id] = {
            'id': id,
            'user_id': user['id'],
            'name': body['name'],
            'menu_item_id': body['menu_item_id'],
            'menu_item_name': priced['name'],
            'selections': priced['selections'],
            'raw_selections': body['selections'],
            'current_price_cents': priced['unit_price_cents'],
            'calories': priced['calories'],
            'is_available': true,
            'times_ordered': 0,
          };
          return _json(_recipes[id]!, 201);
        case ('DELETE', ['recipes', final id]):
          _recipes.remove(id);
          return _json({'message': 'Deleted'});
        case ('POST', ['recipes', final id, 'add-to-cart']):
          final recipe = _recipes[id];
          if (recipe == null) return _error(404, 'Recipe not found');
          final cart = _cart(owner);
          final line = _price(recipe['menu_item_id'] as String,
              recipe['raw_selections'] as List, 1);
          line['line_id'] = _id('line');
          (cart['items'] as List).add(line);
          return _json(_cartOut(cart));
        case ('GET', ['loyalty', 'summary']):
          if (user == null) return _error(401, 'Not authenticated');
          final points = user['loyalty_points'] as int;
          return _json({
            'points': points,
            'lifetime_points': user['lifetime_points'],
            'tier': 'bronze',
            'next_tier': 'silver',
            'points_to_next_tier': 500 - points,
            'points_per_dollar': 10,
            'point_value_cents': 1,
            'min_points_to_redeem': 100,
            'max_redeem_percent': 50,
            'redeemable_value_cents': points,
          });
      }
      return _error(404, 'Not found');
    } on _HttpError catch (e) {
      return _error(e.status, e.message);
    }
  }

  // --------------------------------------------------------------- helpers

  Map<String, dynamic>? _userFor(http.Request r) {
    final auth = r.headers['Authorization'] ?? r.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    final id = _accessTokens[auth.substring(7)];
    return id == null ? null : _users[id];
  }

  Map<String, dynamic> _issue(Map<String, dynamic> user) {
    final token = _id('access');
    _accessTokens[token] = user['id'] as String;
    return {
      'access_token': token,
      'refresh_token': _id('refresh'),
      'token_type': 'bearer',
      'user': _userOut(user),
    };
  }

  Map<String, dynamic> _userOut(Map<String, dynamic> u) => {
        ...u,
        'is_active': true,
        'created_at': _now(),
      };

  Map<String, dynamic>? _viewable(
      String id, Map<String, dynamic>? user, http.Request r) {
    final order = _orders[id];
    if (order == null) return null;
    final token = r.headers['X-Order-Token'] ?? r.headers['x-order-token'];
    if (user != null && order['user_id'] == user['id']) return order;
    if (token != null && token == _orderTokens[id]) return order;
    return null;
  }

  Map<String, dynamic> _itemOut(Map<String, dynamic> item) => {
        ...item,
        'option_groups': [
          for (final g in item['option_groups'] as List)
            {
              ...g as Map<String, dynamic>,
              'options': [
                for (final o in g['options'] as List)
                  {
                    'ingredient_id': o['ingredient_id'],
                    'name': _ingredients[o['ingredient_id']]!['name'],
                    'price_cents':
                        _ingredients[o['ingredient_id']]!['price_cents'],
                    'calories': _ingredients[o['ingredient_id']]!['calories'],
                    'is_default': o['is_default'],
                    'is_available':
                        _ingredients[o['ingredient_id']]!['is_available'],
                  },
              ],
            },
        ],
      };

  /// Same rules as pricing_service.price_line on the server.
  Map<String, dynamic> _price(String itemId, List selections, int quantity) {
    final match = _items.where((i) => i['id'] == itemId);
    if (match.isEmpty) throw _HttpError(404, 'Menu item not found');
    final item = match.first;
    if (item['is_available'] != true) {
      throw _HttpError(409, "'${item['name']}' is currently unavailable");
    }
    final byGroup = <String, List<String>>{};
    for (final s in selections) {
      byGroup
          .putIfAbsent(s['group_key'] as String, () => [])
          .add(s['ingredient_id'] as String);
    }
    var unit = item['base_price_cents'] as int;
    var calories = item['calories'] as int;
    final priced = <Map<String, dynamic>>[];
    for (final g in item['option_groups'] as List) {
      final chosen = byGroup[g['key']] ??
          [
            for (final o in g['options'] as List)
              if (o['is_default'] == true) o['ingredient_id'] as String,
          ];
      if (chosen.length < (g['min_select'] as int)) {
        throw _HttpError(422,
            "Please choose at least ${g['min_select']} option(s) for '${g['name']}'");
      }
      if (chosen.length > (g['max_select'] as int)) {
        throw _HttpError(422,
            "You can choose at most ${g['max_select']} option(s) for '${g['name']}'");
      }
      for (final id in chosen) {
        final ing = _ingredients[id]!;
        if (ing['is_available'] != true) {
          throw _HttpError(409, "'${ing['name']}' is out of stock");
        }
        unit += ing['price_cents'] as int;
        calories += ing['calories'] as int;
        priced.add({
          'group_key': g['key'],
          'group_name': g['name'],
          'ingredient_id': id,
          'name': ing['name'],
          'quantity': 1,
          'price_cents': ing['price_cents'],
        });
      }
    }
    return {
      'menu_item_id': itemId,
      'name': item['name'],
      'item_type': item['item_type'],
      'quantity': quantity,
      'unit_price_cents': unit,
      'line_total_cents': unit * quantity,
      'selections': priced,
      'calories': calories,
      'allergens': item['allergens'],
    };
  }

  Map<String, dynamic> _cart(String owner) => _carts.putIfAbsent(
      owner,
      () => {
            'id': _id('cart'),
            'items': <dynamic>[],
            'table': null,
            'order_type': 'dine_in'
          });

  Map<String, dynamic>? _line(Map<String, dynamic> cart, String lineId) {
    for (final l in cart['items'] as List) {
      if (l['line_id'] == lineId) return l as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic> _totals(Map<String, dynamic> cart, {int redeem = 0}) {
    final subtotal = (cart['items'] as List)
        .fold<int>(0, (s, l) => s + (l['line_total_cents'] as int));
    final discount =
        redeem > 0 ? (redeem < subtotal ~/ 2 ? redeem : subtotal ~/ 2) : 0;
    final tax = ((subtotal - discount) * 0.1).round();
    return {
      'subtotal_cents': subtotal,
      'discount_cents': discount,
      'points_redeemed': discount,
      'tax_rate': 0.1,
      'tax_cents': tax,
      'service_fee_cents': 0,
      'tip_cents': 0,
      'total_cents': subtotal - discount + tax,
    };
  }

  Map<String, dynamic> _cartOut(Map<String, dynamic> cart) => {
        'id': cart['id'],
        'items': [
          for (final l in cart['items'] as List)
            {
              for (final e in (l as Map).entries)
                if (e.key != 'raw_selections') e.key: e.value
            },
        ],
        'item_count': (cart['items'] as List)
            .fold<int>(0, (s, l) => s + (l['quantity'] as int)),
        'table': cart['table'],
        'order_type': cart['order_type'],
        'totals': _totals(cart),
        'currency': 'aud',
        'has_errors': false,
      };

  String _id(String prefix) => '${prefix}_${++_seq}';

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static String _inMinutes(int m) =>
      DateTime.now().toUtc().add(Duration(minutes: m)).toIso8601String();

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  static http.Response _error(int status, String detail) =>
      _json({'detail': detail}, status);
}

class _HttpError implements Exception {
  _HttpError(this.status, this.message);
  final int status;
  final String message;
}

/// An AppState talking to a fresh [FakeBackend], with saved preferences
/// already set up. Live WebSocket updates are off: tests poll.
Future<(AppState, FakeBackend)> fakeAppState(
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await TokenStore.open();
  final backend = FakeBackend();
  final api = RoboKitchenApi(
      store: store, client: ApiClient(store: store, client: backend.client));
  return (AppState(api: api, store: store, liveUpdates: false), backend);
}
