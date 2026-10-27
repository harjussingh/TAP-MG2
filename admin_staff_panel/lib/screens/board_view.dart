import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'order_sheet.dart';

const boardColumns = [
  ('confirmed', 'In queue', RK.queued),
  ('preparing', 'Robot cooking', RK.cooking),
  ('ready', 'Ready to hand over', RK.ready),
  ('pending_payment', 'Awaiting payment', RK.awaiting),
];

typedef BoardData = ({List<Map<String, dynamic>> orders, Map<String, dynamic>? summary});

List<Map<String, dynamic>> asMapList(Object? v) =>
    v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];

/// Order status change / payment shared by the board and the order sheet.
Future<bool> setOrderStatus(BuildContext context, Map<String, dynamic> o, String status) {
  final api = AppScope.read(context).api;
  return runAction(context, () => api.patch('/staff/orders/${o['id']}/status', {'status': status}),
      'Order #${o['order_number']} → ${human(status)}');
}

Future<bool> markOrderPaid(BuildContext context, Map<String, dynamic> o) {
  final api = AppScope.read(context).api;
  return runAction(context, () => api.post('/staff/orders/${o['id']}/mark-paid'),
      'Payment recorded for #${o['order_number']}');
}

class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.refresh});
  final Listenable refresh;

  Future<BoardData> _load(AppState s) async {
    final qs = boardColumns.map((c) => 'status=${c.$1}').join('&');
    final page = await s.api.get('/staff/orders?$qs&size=50') as Map<String, dynamic>;
    Map<String, dynamic>? summary;
    try {
      summary = (await s.api.get('/staff/orders/summary') as Map).cast<String, dynamic>();
    } catch (_) {}
    return (orders: asMapList(page['items']), summary: summary);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    return AsyncView<BoardData>(
      refresh: refresh,
      load: () => _load(s),
      builder: (context, data, reload) => _Board(data: data, reload: reload),
    );
  }
}

class _Board extends StatefulWidget {
  const _Board({required this.data, required this.reload});
  final BoardData data;
  final Future<void> Function() reload;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Repaint the waiting timers every second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() fn) async {
    if (await fn()) await widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final summary = widget.data.summary;
    final now = DateTime.now();

    Widget column((String, String, Color) col, {double? width}) {
      final list = widget.data.orders.where((o) => o['status'] == col.$1).toList()
        ..sort((a, b) => (parseTime(a['created_at']) ?? now).compareTo(parseTime(b['created_at']) ?? now));
      final body = Container(
        width: width,
        decoration: BoxDecoration(color: RK.surface.withValues(alpha: 0.5), border: Border.all(color: RK.lineSoft),
            borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: col.$3, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(child: Text(col.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${list.length}', style: const TextStyle(color: RK.muted)),
            ]),
            const SizedBox(height: 10),
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(4), child: Muted('Nothing here.')),
            for (final o in list) ...[
              _Ticket(
                order: o,
                isNew: state.isFresh(o['id'], now),
                now: now,
                onStatus: (st) => _act(() => setOrderStatus(context, o, st)),
                onPaid: () => _act(() => markOrderPaid(context, o)),
                onDetails: () => showOrderSheet(context, o['id'] as String, onChanged: widget.reload),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
      return body;
    }

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 640 ? 2 : 1);
      final gap = 12.0;
      final colWidth = (c.maxWidth - gap * (cols - 1)) / cols;
      return ListView(
        children: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final col in boardColumns)
                    Tag('${summary[col.$1] ?? 0} ${col.$2.toLowerCase()}', color: RK.muted),
                  const SizedBox(width: 6),
                  Muted('${summary['kitchen_queue'] ?? 0} jobs queued'
                      '${(summary['kitchen_failed'] ?? 0) != 0 ? ' · ${summary['kitchen_failed']} failed' : ''}'),
                ],
              ),
            ),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [for (final col in boardColumns) column(col, width: colWidth)],
          ),
        ],
      );
    });
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.order, required this.isNew, required this.now, required this.onStatus,
      required this.onPaid, required this.onDetails});
  final Map<String, dynamic> order;
  final bool isNew;
  final DateTime now;
  final ValueChanged<String> onStatus;
  final VoidCallback onPaid, onDetails;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final items = asMapList(o['items']);
    final payment = (o['payment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final paid = payment['status'] == 'paid';
    final status = o['status'] as String?;
    final waited = secondsSince(o['created_at'], now);
    final timerColor = waited > 600 ? RK.alert : (waited > 300 ? RK.cooking : RK.muted);

    return Container(
      key: Key('ticket-${o['order_number']}'),
      decoration: BoxDecoration(
        color: RK.surface,
        border: Border.all(color: isNew ? RK.cooking : RK.line),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${o['order_number']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(whereLabel(o), style: const TextStyle(color: RK.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${mmss(waited)} waiting', style: TextStyle(color: timerColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Tag(paid ? 'paid' : '${human(payment['method'])} · unpaid', color: paid ? RK.ready : RK.cooking),
            ]),
          ]),
          const SizedBox(height: 10),
          for (final i in items.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 30, child: Text('${i['quantity']}×', style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['name']}'),
                    if (asMapList(i['selections']).isNotEmpty)
                      Text(asMapList(i['selections']).map((s) => s['name']).join(', '),
                          style: const TextStyle(color: RK.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
                    if ((i['special_instructions'] ?? '').toString().isNotEmpty)
                      Text('${i['special_instructions']}',
                          style: const TextStyle(color: RK.cooking, fontSize: 12.5, fontStyle: FontStyle.italic)),
                  ]),
                ),
              ]),
            ),
          if (items.length > 4) Muted('+${items.length - 4} more'),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (status == 'confirmed') _primary('Start cooking', () => onStatus('preparing')),
            if (status == 'preparing') _primary('Ready', () => onStatus('ready')),
            if (status == 'ready') _primary('Handed over', () => onStatus('completed')),
            if (!paid && status != 'cancelled')
              OutlinedButton(onPressed: onPaid, style: _small, child: const Text('Take payment')),
            OutlinedButton(onPressed: onDetails, style: _small, child: const Text('Details')),
          ]),
        ],
      ),
    );
  }

  static final _small = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(0, 34));

  Widget _primary(String label, VoidCallback onTap) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 34)),
        child: Text(label),
      );
}
