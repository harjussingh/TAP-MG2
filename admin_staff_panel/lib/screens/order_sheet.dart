import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'board_view.dart';

/// Opens the order details panel from the right (a full-screen dialog on phones).
Future<void> showOrderSheet(BuildContext context, String orderId, {Future<void> Function()? onChanged}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close order',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: _OrderSheet(orderId: orderId, onChanged: onChanged),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
      child: child,
    ),
  );
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.orderId, this.onChanged});
  final String orderId;
  final Future<void> Function()? onChanged;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  Map<String, dynamic>? _order;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await AppScope.read(context).api.get('/staff/orders/${widget.orderId}') as Map<String, dynamic>;
      if (mounted) setState(() => _order = o);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _after(bool ok) async {
    if (!ok) return;
    await widget.onChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _guard(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> o) => _guard(() async {
        final reason = await askText(context, 'Why is this order being cancelled?', confirm: 'Cancel order');
        if (reason == null || !mounted) return;
        final api = AppScope.read(context).api;
        await _after(await runAction(context, () => api.post('/staff/orders/${o['id']}/cancel', {'reason': reason}),
            'Order #${o['order_number']} cancelled'));
      });

  Future<void> _refund(Map<String, dynamic> o) => _guard(() async {
        final reason = await askText(context, 'Reason for the refund?', confirm: 'Refund');
        if (reason == null || !mounted) return;
        final api = AppScope.read(context).api;
        await _after(await runAction(context, () => api.post('/admin/orders/${o['id']}/refund', {'reason': reason}),
            'Order #${o['order_number']} refunded'));
      });

  Future<void> _paid(Map<String, dynamic> o) => _guard(() async => _after(await markOrderPaid(context, o)));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: RK.surface,
      child: SizedBox(
        width: width < 560 ? width : 460,
        height: double.infinity,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RK.line))),
              child: Row(children: [
                Expanded(
                  child: Text(_order == null ? 'Order' : 'Order #${_order!['order_number']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                OutlinedButton(key: const Key('close-order'), onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close')),
              ]),
            ),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('$_error', style: const TextStyle(color: RK.alert))));
    }
    final o = _order;
    if (o == null) return const Center(child: CircularProgressIndicator());

    final isManager = AppScope.read(context).isManager;
    final p = (o['pricing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pay = (o['payment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final customer = (o['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status = o['status'] as String?;
    final paid = pay['status'] == 'paid';
    final taxRate = (p['tax_rate'] is num) ? ((p['tax_rate'] as num) * 100).round() : 0;

    Widget line(String a, String b, {bool bold = false, bool muted = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(color: muted ? RK.muted : RK.text, fontWeight: bold ? FontWeight.w700 : null))),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null)),
          ]),
        );

    final who = [
      customer['name'] ?? 'Guest',
      if (customer['email'] != null) customer['email'],
      if (customer['phone'] != null) customer['phone'],
    ].join(' · ');

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        StatusChip(status),
        const Spacer(),
        Muted('${whereLabel(o)} · ${clock(o['created_at'])}'),
      ]),
      const SizedBox(height: 12),
      Muted(who),
      if ((o['notes'] ?? '').toString().isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: RK.cooking, width: 3))),
          child: Text('${o['notes']}'),
        ),
      ],
      const SizedBox(height: 14),
      for (final i in asMapList(o['items']))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i['quantity']}× ${i['name']}'),
                if (asMapList(i['selections']).isNotEmpty)
                  Muted(asMapList(i['selections']).map((s) => s['name']).join(', '), size: 12),
                if ((i['special_instructions'] ?? '').toString().isNotEmpty)
                  Text('${i['special_instructions']}', style: const TextStyle(color: RK.cooking, fontSize: 12)),
              ]),
            ),
            Text(money(i['line_total_cents'])),
          ]),
        ),
      const Divider(height: 22),
      line('Subtotal', money(p['subtotal_cents']), muted: true),
      if ((p['discount_cents'] ?? 0) != 0) line('Points discount', '-${money(p['discount_cents'])}', muted: true),
      line('$taxLabel ($taxRate%)', money(p['tax_cents']), muted: true),
      if ((p['service_fee_cents'] ?? 0) != 0) line('Service fee', money(p['service_fee_cents']), muted: true),
      if ((p['tip_cents'] ?? 0) != 0) line('Tip', money(p['tip_cents']), muted: true),
      line('Total', money(p['total_cents']), bold: true),
      const SizedBox(height: 10),
      Muted('Payment: ${human(pay['method'])} · ${pay['status'] ?? ''}'),
      const SizedBox(height: 18),
      const Text('Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      for (final h in asMapList(o['status_history'])) line(human(h['status']), clock(h['at']), muted: false),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!paid && status != 'cancelled')
          FilledButton(key: const Key('sheet-take-payment'), onPressed: _busy ? null : () => _paid(o),
              child: const Text('Take payment')),
        if (status != 'completed' && status != 'cancelled')
          FilledButton(
            key: const Key('sheet-cancel'),
            style: FilledButton.styleFrom(backgroundColor: RK.alert, foregroundColor: Colors.white),
            onPressed: _busy ? null : () => _cancel(o),
            child: const Text('Cancel order'),
          ),
        if (isManager && paid)
          OutlinedButton(key: const Key('sheet-refund'), onPressed: _busy ? null : () => _refund(o),
              child: const Text('Refund')),
      ]),
    ]);
  }
}
