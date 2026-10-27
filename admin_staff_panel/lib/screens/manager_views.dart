import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../app_state.dart';
import '../download/download.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'board_view.dart';
import 'order_sheet.dart';
import 'staff_views.dart';

void _applySettings(Map<String, dynamic> s) {
  currencyCode = '${s['currency'] ?? 'aud'}'.toUpperCase();
  taxLabel = '${s['tax_label'] ?? 'GST'}';
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

// ---------------------------------------------------------------- today

typedef OverviewData = ({Map<String, dynamic> dash, Map<String, dynamic> settings});

class OverviewView extends StatelessWidget {
  const OverviewView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<OverviewData>(
      refresh: refresh,
      load: () async {
        final r = await Future.wait([api.get('/admin/dashboard'), api.get('/admin/settings')]);
        final s = (r[1] as Map).cast<String, dynamic>();
        _applySettings(s);
        return (dash: (r[0] as Map).cast<String, dynamic>(), settings: s);
      },
      builder: (context, data, reload) {
        final d = data.dash;
        final rating = d['average_rating'];
        final kpis = [
          ('Takings', money(d['revenue_cents'])),
          ('Orders', '${d['orders_total'] ?? 0}'),
          ('Completed', '${d['orders_completed'] ?? 0}'),
          ('Average order', money(d['average_order_cents'])),
          ('$taxLabel collected', money(d['tax_cents'])),
          ('Tips', money(d['tips_cents'])),
          ('Open now', '${d['active_orders'] ?? 0}'),
          ('Rating', rating is num ? '${rating.toStringAsFixed(1)} ★' : '—'),
        ];
        final top = asMapList(d['top_items']);
        final byType = (d['orders_by_type'] as Map?)?.cast<String, dynamic>() ?? const {};
        final dineIn = _int(byType['dine_in']);
        final takeaway = _int(byType['takeaway']);
        final total = (dineIn + takeaway) == 0 ? 1 : dineIn + takeaway;

        Widget mixRow(String label, int n) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Expanded(child: Text(label)), Muted('$n')]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: n / total, minHeight: 6, backgroundColor: RK.surface2, color: RK.queued),
                ),
              ]),
            );

        return ListView(children: [
          LayoutBuilder(builder: (context, c) {
            final per = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
            final w = (c.maxWidth - 12 * (per - 1)) / per;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final k in kpis)
                SizedBox(
                  width: w,
                  child: Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.$2, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                      Muted(k.$1),
                    ]),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 14),
          if (data.settings['is_accepting_orders'] == false)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Panel(accent: RK.alert, child: Text('Ordering is paused. Customers cannot check out. Turn it back on in Settings.')),
            ),
          if (_int(d['kitchen_failed_jobs']) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(accent: RK.cooking, child: Text('${d['kitchen_failed_jobs']} robot job(s) failed. Open the order board to retry them.')),
            ),
          TwoColumns(children: [
            Panel(
              title: 'Best sellers today',
              child: top.isEmpty
                  ? const Muted('No sales yet today.')
                  : Column(children: [
                      for (final i in top.take(8))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(child: Text('${i['name']}')),
                            Muted('${i['quantity']} sold'),
                            const SizedBox(width: 16),
                            Text(money(i['revenue_cents'])),
                          ]),
                        ),
                    ]),
            ),
            Panel(
              title: 'Where orders come from',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                mixRow('Dine in', dineIn),
                mixRow('Takeaway', takeaway),
                Muted('${d['new_customers'] ?? 0} new customer account(s) today.'),
              ]),
            ),
          ]),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- orders

const _orderStatuses = ['pending_payment', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled'];

class OrdersView extends StatefulWidget {
  const OrdersView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  String _status = '';
  String _number = '';
  int _page = 1;
  int _filterVersion = 0;
  Timer? _debounce;
  bool _downloading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setFilter({String? status, String? number}) {
    setState(() {
      if (status != null) _status = status;
      if (number != null) _number = number;
      _page = 1;
      _filterVersion++;
    });
  }

  Future<void> _csv() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final api = AppScope.read(context).api;
    String? where;
    await runAction(context, () async {
      final bytes = await api.bytes('/admin/reports/orders.csv');
      where = await saveFile('orders.csv', bytes, 'text/csv');
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    if (where != null) toast(context, where!);
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    final qs = <String, String>{'size': '30', 'page': '$_page'};
    if (_status.isNotEmpty) qs['status'] = _status;
    if (RegExp(r'^\d+$').hasMatch(_number)) qs['order_number'] = _number;
    final query = Uri(queryParameters: qs).query;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            key: const Key('order-status-filter'),
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All statuses')),
              for (final s in _orderStatuses) DropdownMenuItem(value: s, child: Text(human(s))),
            ],
            onChanged: (v) => _setFilter(status: v ?? ''),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            key: const Key('order-search'),
            decoration: const InputDecoration(labelText: 'Order number'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                if (mounted) _setFilter(number: v.trim());
              });
            },
          ),
        ),
        OutlinedButton.icon(
          key: const Key('download-csv'),
          onPressed: _downloading ? null : _csv,
          icon: const Icon(Icons.download, size: 16),
          label: Text(_downloading ? 'Downloading…' : 'Download CSV'),
        ),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: AsyncView<Map<String, dynamic>>(
          key: ValueKey('orders-$_filterVersion-$_page'),
          refresh: widget.refresh,
          load: () async => (await api.get('/admin/orders?$query') as Map).cast<String, dynamic>(),
          builder: (context, page, reload) {
            final items = asMapList(page['items']);
            final pages = _int(page['pages']) < 1 ? 1 : _int(page['pages']);
            if (items.isEmpty) return const Align(alignment: Alignment.topCenter, child: EmptyNote('No orders match this filter.'));
            return ListView(children: [
              SimpleTable(
                columns: const ['#', 'Placed', 'Where', 'Customer', 'Status', 'Payment', 'Total', ''],
                numeric: const {6},
                rows: [
                  for (final o in items)
                    [
                      Text('${o['order_number']}'),
                      Muted(dayTime(o['created_at'])),
                      Text(whereLabel(o)),
                      Text('${(o['customer'] as Map?)?['name'] ?? 'Guest'}'),
                      StatusChip(o['status'] as String?),
                      Muted('${human((o['payment'] as Map?)?['method'])} · ${(o['payment'] as Map?)?['status'] ?? ''}'),
                      Text(money((o['pricing'] as Map?)?['total_cents'])),
                      OutlinedButton(
                        onPressed: () => showOrderSheet(context, o['id'] as String, onChanged: reload),
                        child: const Text('Open'),
                      ),
                    ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Muted('${page['total'] ?? items.length} order(s) · page $_page of $pages'),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: _page > 1 ? () => setState(() => _page--) : null,
                      child: const Text('Previous'),
                    ),
                    OutlinedButton(
                      onPressed: _page < pages ? () => setState(() => _page++) : null,
                      child: const Text('Next'),
                    ),
                  ]),
                ],
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- menu

typedef MenuData = ({List<Map<String, dynamic>> items, Map<String, String> categories});

class MenuView extends StatelessWidget {
  const MenuView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<MenuData>(
      refresh: refresh,
      load: () async {
        final r = await Future.wait([api.get('/staff/menu-items'), api.get('/menu/categories')]);
        return (
          items: asMapList(r[0]),
          categories: {for (final c in asMapList(r[1])) '${c['id']}': '${c['name']}'},
        );
      },
      builder: (context, data, reload) {
        return ListView(children: [
          const Muted('Prices and options are edited through the menu endpoints (API docs, "Admin - menu"); '
              'availability can be switched here.'),
          const SizedBox(height: 12),
          SimpleTable(
            columns: const ['Dish', 'Category', 'Type', 'Price', 'Rating', 'On sale'],
            numeric: const {3},
            rows: [
              for (final i in data.items)
                [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${i['name']}'),
                    if (i['is_featured'] == true) ...[const SizedBox(width: 8), const Tag('featured', color: RK.cooking)],
                  ]),
                  Muted(data.categories['${i['category_id']}'] ?? '—'),
                  Muted(i['item_type'] == 'custom_bowl' ? 'bowl builder' : 'standard'),
                  Text(money(i['base_price_cents'])),
                  Muted(i['rating_avg'] is num
                      ? '${(i['rating_avg'] as num).toStringAsFixed(1)} ★ (${i['rating_count'] ?? 0})'
                      : '—'),
                  SizedBox(
                    width: 70,
                    child: _InlineSwitch(
                      key: Key('menu-${i['id']}'),
                      initial: i['is_available'] == true,
                      save: (v) => api.patch('/staff/menu-items/${i['id']}/availability', {'is_available': v}),
                      message: (v) => '${i['name']} is ${v ? 'available' : 'sold out'}',
                    ),
                  ),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

/// Bare switch that saves immediately and rolls back if the save fails.
class _InlineSwitch extends StatefulWidget {
  const _InlineSwitch({super.key, required this.initial, required this.save, required this.message});
  final bool initial;
  final Future<dynamic> Function(bool) save;
  final String Function(bool) message;

  @override
  State<_InlineSwitch> createState() => _InlineSwitchState();
}

class _InlineSwitchState extends State<_InlineSwitch> {
  late bool _on = widget.initial;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _InlineSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.initial != widget.initial) _on = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Switch(
        value: _on,
        onChanged: _saving
            ? null
            : (v) async {
                setState(() {
                  _on = v;
                  _saving = true;
                });
                final ok = await runAction(context, () async => widget.save(v), widget.message(v));
                if (!mounted) return;
                setState(() {
                  _saving = false;
                  if (!ok) _on = !v;
                });
              },
      );
}

// ---------------------------------------------------------------- tables & QR

class TablesView extends StatelessWidget {
  const TablesView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<List<Map<String, dynamic>>>(
      refresh: refresh,
      load: () async => asMapList(await api.get('/admin/tables')),
      builder: (context, tables, reload) {
        final active = tables.where((t) => t['is_active'] == true).map((t) => t['number']).join(', ');
        return ListView(children: [
          Panel(
            title: 'One QR for the whole venue',
            child: Wrap(spacing: 18, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              QrImage(api: api, path: '/admin/tables/venue-qr.png', size: 150, name: 'venue-qr.png'),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Muted('Print this once. After scanning, the customer types their table number.'),
                  const SizedBox(height: 8),
                  Text('Table numbers in service: ${active.isEmpty ? '—' : active}'),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TwoColumns(children: [
            for (final t in tables)
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('${t['name'] ?? 'Table ${t['number']}'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    Tag(t['is_active'] == true ? '${t['seats'] ?? '?'} seats' : 'out of service'),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    // Keyed by code so a regenerated code reloads the image.
                    QrImage(key: ValueKey('qr-${t['code']}'), api: api, path: '/admin/tables/${t['id']}/qr.png',
                        size: 120, name: 'table-${t['number']}-qr.png'),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Per-table QR'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await runAction(context, () => api.post('/admin/tables/${t['id']}/regenerate-code'),
                              'New code generated — reprint this QR');
                          if (ok) await reload();
                        },
                        child: const Text('Regenerate code'),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText('${t['scan_url'] ?? ''}', style: const TextStyle(color: RK.muted, fontSize: 12)),
                ]),
              ),
          ]),
        ]);
      },
    );
  }
}

/// QR code image fetched with the signed-in user's token. Tap to enlarge or download.
class QrImage extends StatefulWidget {
  const QrImage({super.key, required this.api, required this.path, required this.size, required this.name});
  final ApiClient api;
  final String path, name;
  final double size;

  @override
  State<QrImage> createState() => _QrImageState();
}

class _QrImageState extends State<QrImage> {
  late final Future<Uint8List> _bytes = widget.api.bytes(widget.path);

  void _open(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Image.memory(bytes, width: 360, height: 360)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              final where = await saveFile(widget.name, bytes, 'image/png');
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) toast(context, where);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download PNG'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        Widget inner;
        if (snap.hasData) {
          inner = Image.memory(snap.data!, width: widget.size, height: widget.size, filterQuality: FilterQuality.none);
        } else if (snap.hasError) {
          inner = const Center(child: Text('QR unavailable', style: TextStyle(color: Colors.black54, fontSize: 12)));
        } else {
          inner = const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return Tooltip(
          message: snap.hasData ? 'Open full size' : '',
          child: InkWell(
            onTap: snap.hasData ? () => _open(snap.data!) : null,
            child: Container(
              width: widget.size + 12,
              height: widget.size + 12,
              color: Colors.white,
              padding: const EdgeInsets.all(6),
              child: inner,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- reviews

class ReviewsView extends StatelessWidget {
  const ReviewsView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<List<Map<String, dynamic>>>(
      refresh: refresh,
      load: () async => asMapList((await api.get('/admin/reviews?size=30') as Map)['items']),
      builder: (context, reviews, reload) {
        if (reviews.isEmpty) {
          return const Align(
            alignment: Alignment.topCenter,
            child: EmptyNote('No reviews yet. They appear after a completed order is rated.'),
          );
        }
        return ListView.separated(
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = reviews[i];
            final stars = _int(r['rating']).clamp(0, 5);
            final visible = r['is_visible'] == true;
            return Panel(
              accent: visible ? null : RK.dim,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                  Text('${'★' * stars}${'☆' * (5 - stars)}', style: const TextStyle(color: RK.cooking, fontSize: 18)),
                  Muted('#${r['order_number']} · ${r['author_name'] ?? 'Guest'} · ${dayTime(r['created_at'])}'
                      '${visible ? '' : ' · hidden'}'),
                ]),
                const SizedBox(height: 6),
                (r['comment'] ?? '').toString().isEmpty ? const Muted('No comment left.') : Text('${r['comment']}'),
                if ((r['staff_reply'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: RK.queued, width: 3))),
                    child: Text('Your reply: ${r['staff_reply']}'),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await runAction(context, () => api.patch('/admin/reviews/${r['id']}', {'is_visible': !visible}),
                          visible ? 'Review hidden' : 'Review shown');
                      if (ok) await reload();
                    },
                    child: Text(visible ? 'Hide' : 'Show'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final reply = await askText(context, 'Reply to this review',
                          initial: '${r['staff_reply'] ?? ''}', confirm: 'Save reply');
                      if (reply == null || !context.mounted) return;
                      final ok = await runAction(context, () => api.patch('/admin/reviews/${r['id']}', {'staff_reply': reply}),
                          'Reply saved');
                      if (ok) await reload();
                    },
                    child: Text((r['staff_reply'] ?? '').toString().isEmpty ? 'Reply' : 'Edit reply'),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------- team

class TeamView extends StatelessWidget {
  const TeamView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final api = state.api;
    return AsyncView<List<Map<String, dynamic>>>(
      refresh: refresh,
      load: () async => asMapList((await api.get('/admin/users?size=50') as Map)['items']),
      builder: (context, users, reload) {
        return ListView(children: [
          _AddMember(onCreated: reload),
          const SizedBox(height: 14),
          SimpleTable(
            columns: const ['Name', 'Email', 'Station', 'Points', 'Last signed in', 'Active'],
            rows: [
              for (final u in users)
                [
                  Text('${u['full_name']}'),
                  Muted('${u['email']}'),
                  Text(switch (u['role']) { 'admin' => 'manager', 'staff' => 'kitchen', _ => 'customer' }),
                  Muted('${u['loyalty_points'] ?? 0}'),
                  Muted(u['last_login_at'] == null ? 'never' : dayTime(u['last_login_at'])),
                  // You cannot deactivate yourself and lock everyone out.
                  u['id'] == state.user?['id']
                      ? const Muted('you')
                      : SizedBox(
                          width: 70,
                          child: _InlineSwitch(
                            key: Key('user-${u['id']}'),
                            initial: u['is_active'] == true,
                            save: (v) => api.patch('/admin/users/${u['id']}', {'is_active': v}),
                            message: (v) => '${u['full_name']} ${v ? 'reactivated' : 'deactivated'}',
                          ),
                        ),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class _AddMember extends StatefulWidget {
  const _AddMember({required this.onCreated});
  final Future<void> Function() onCreated;

  @override
  State<_AddMember> createState() => _AddMemberState();
}

class _AddMemberState extends State<_AddMember> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'staff';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final api = AppScope.read(context).api;
    final ok = await runAction(
      context,
      () => api.post('/admin/users', {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'role': _role,
      }),
      'Account created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _name.clear();
      _email.clear();
      _password.clear();
      await widget.onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      TextFormField(
        key: const Key('tm-name'),
        controller: _name,
        decoration: const InputDecoration(labelText: 'Full name'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
      ),
      TextFormField(
        key: const Key('tm-email'),
        controller: _email,
        decoration: const InputDecoration(labelText: 'Work email'),
        keyboardType: TextInputType.emailAddress,
        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
      ),
      TextFormField(
        key: const Key('tm-password'),
        controller: _password,
        decoration: const InputDecoration(labelText: 'Temporary password'),
        validator: (v) {
          final s = v ?? '';
          if (s.length < 8) return 'At least 8 characters';
          if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) return 'Use letters and numbers';
          return null;
        },
      ),
      DropdownButtonFormField<String>(
        key: const Key('tm-role'),
        initialValue: _role,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Station'),
        items: const [
          DropdownMenuItem(value: 'staff', child: Text('Kitchen staff')),
          DropdownMenuItem(value: 'admin', child: Text('Manager')),
        ],
        onChanged: (v) => setState(() => _role = v ?? 'staff'),
      ),
    ];
    return Panel(
      title: 'Add a team member',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TwoColumns(gap: 12, children: fields),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('tm-create'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Creating…' : 'Create account'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- settings

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<Map<String, dynamic>>(
      refresh: refresh,
      load: () async {
        final s = (await api.get('/admin/settings') as Map).cast<String, dynamic>();
        _applySettings(s);
        return s;
      },
      // Keyed by the loaded values so a reload refills the form.
      builder: (context, s, reload) => _SettingsForm(key: ValueKey(s.toString()), initial: s, onSaved: reload),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({super.key, required this.initial, required this.onSaved});
  final Map<String, dynamic> initial;
  final Future<void> Function() onSaved;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _open = widget.initial['is_accepting_orders'] == true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final tax = s['tax_rate'] is num ? ((s['tax_rate'] as num) * 100).toStringAsFixed(2) : '10.00';
    _c = {
      'restaurant_name': TextEditingController(text: '${s['restaurant_name'] ?? ''}'),
      'currency': TextEditingController(text: '${s['currency'] ?? 'aud'}'),
      'tax_label': TextEditingController(text: '${s['tax_label'] ?? 'GST'}'),
      'tax_rate': TextEditingController(text: tax),
      'service_fee_cents': TextEditingController(text: '${s['service_fee_cents'] ?? 0}'),
      'avg_prep_minutes': TextEditingController(text: '${s['avg_prep_minutes'] ?? 4}'),
      'points_per_dollar': TextEditingController(text: '${s['points_per_dollar'] ?? 0}'),
      'point_value_cents': TextEditingController(text: '${s['point_value_cents'] ?? 1}'),
      'min_points_to_redeem': TextEditingController(text: '${s['min_points_to_redeem'] ?? 0}'),
      'max_redeem_percent': TextEditingController(text: '${s['max_redeem_percent'] ?? 0}'),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? Function(String?) _number(num min, num max, {bool decimal = false}) => (v) {
        final n = decimal ? double.tryParse((v ?? '').trim()) : int.tryParse((v ?? '').trim());
        if (n == null) return decimal ? 'Enter a number' : 'Enter a whole number';
        if (n < min || n > max) return 'Between $min and $max';
        return null;
      };

  Widget _field(String key, String label, {String? Function(String?)? validator, bool numeric = false, bool decimal = false,
      int? maxLength}) {
    return TextFormField(
      key: Key('set-$key'),
      controller: _c[key],
      decoration: InputDecoration(labelText: label, counterText: ''),
      maxLength: maxLength,
      keyboardType: numeric ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))] : null,
      validator: validator,
    );
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final api = AppScope.read(context).api;
    int i(String k) => int.parse(_c[k]!.text.trim());
    final body = {
      'restaurant_name': _c['restaurant_name']!.text.trim(),
      'currency': _c['currency']!.text.trim().toLowerCase(),
      'tax_label': _c['tax_label']!.text.trim(),
      'tax_rate': double.parse(_c['tax_rate']!.text.trim()) / 100,
      'service_fee_cents': i('service_fee_cents'),
      'avg_prep_minutes': i('avg_prep_minutes'),
      'is_accepting_orders': _open,
      'points_per_dollar': i('points_per_dollar'),
      'point_value_cents': i('point_value_cents'),
      'min_points_to_redeem': i('min_points_to_redeem'),
      'max_redeem_percent': i('max_redeem_percent'),
    };
    final ok = await runAction(context, () => api.patch('/admin/settings', body), 'Settings saved');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    return Form(
      key: _form,
      child: ListView(children: [
        TwoColumns(children: [
          Panel(
            title: 'Service',
            child: Column(children: [
              _field('restaurant_name', 'Restaurant name', validator: required, maxLength: 80),
              const SizedBox(height: 12),
              _field('currency', 'Currency (ISO code)', maxLength: 3,
                  validator: (v) => RegExp(r'^[A-Za-z]{3}$').hasMatch((v ?? '').trim()) ? null : 'Three letters, e.g. AUD'),
              const SizedBox(height: 12),
              _field('tax_label', 'Tax shown on receipts as', validator: required, maxLength: 20),
              const SizedBox(height: 12),
              _field('tax_rate', 'Tax rate %', numeric: true, decimal: true, validator: _number(0, 50, decimal: true)),
              const SizedBox(height: 12),
              _field('service_fee_cents', 'Service fee (cents)', numeric: true, validator: _number(0, 100000)),
              const SizedBox(height: 12),
              _field('avg_prep_minutes', 'Average prep time (minutes)', numeric: true, validator: _number(1, 120)),
              const SizedBox(height: 6),
              SwitchListTile(
                key: const Key('set-open'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepting orders'),
                subtitle: Text(_open ? 'Customers can check out' : 'Ordering is paused',
                    style: TextStyle(color: _open ? RK.muted : RK.alert)),
                value: _open,
                onChanged: (v) => setState(() => _open = v),
              ),
            ]),
          ),
          Panel(
            title: 'Loyalty points',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Muted('Customers earn points on paid orders and redeem them at checkout.'),
              const SizedBox(height: 12),
              _field('points_per_dollar', 'Points earned per dollar', numeric: true, validator: _number(0, 1000)),
              const SizedBox(height: 12),
              _field('point_value_cents', 'Value of one point (cents)', numeric: true, validator: _number(1, 1000)),
              const SizedBox(height: 12),
              _field('min_points_to_redeem', 'Minimum points to redeem', numeric: true, validator: _number(0, 1000000)),
              const SizedBox(height: 12),
              _field('max_redeem_percent', 'Most of an order points can cover (%)', numeric: true, validator: _number(0, 100)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('save-settings'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save settings'),
          ),
        ),
      ]),
    );
  }
}
