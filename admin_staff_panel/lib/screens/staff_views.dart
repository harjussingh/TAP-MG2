import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'board_view.dart';

// ---------------------------------------------------------------- robot queue

const _jobLabel = {
  'queued': 'Queued',
  'assigned': 'Claimed',
  'cooking': 'Cooking',
  'done': 'Done',
  'failed': 'Failed',
  'cancelled': 'Cancelled',
};

String _jobStatusAsOrder(String? s) => switch (s) {
      'cooking' => 'preparing',
      'done' => 'completed',
      'failed' || 'cancelled' => 'cancelled',
      _ => 'confirmed',
    };

class RobotView extends StatelessWidget {
  const RobotView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<List<Map<String, dynamic>>>(
      refresh: refresh,
      load: () async => asMapList(await api.get('/staff/kitchen/jobs')),
      builder: (context, jobs, reload) {
        return ListView(children: [
          const Muted('Jobs the robot picks up. Cooking and done are reported by the robot itself; '
              'use retry when a job fails.'),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            const EmptyNote('The queue is empty. New paid orders appear here straight away.')
          else
            SimpleTable(
              columns: const ['Job', 'Order', 'Items', 'Station', 'Status', 'Progress', ''],
              rows: [
                for (final j in jobs)
                  [
                    Muted(_shortId(j['id'])),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('#${j['order_number']}'),
                      if (j['table_number'] != null) Muted('Table ${j['table_number']}', size: 12),
                    ]),
                    Text(asMapList(j['items']).map((i) => '${i['quantity']}× ${i['name']}').join('\n')),
                    Muted('${j['station'] ?? '—'}'),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      StatusChip(_jobStatusAsOrder(j['status'] as String?), label: _jobLabel[j['status']] ?? '${j['status']}'),
                      if ((j['message'] ?? '').toString().isNotEmpty) Muted('${j['message']}', size: 12),
                    ]),
                    SizedBox(
                      width: 110,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ((j['progress'] is num) ? (j['progress'] as num).toDouble() : 0) / 100,
                          minHeight: 6,
                          backgroundColor: RK.surface2,
                          color: RK.cooking,
                        ),
                      ),
                    ),
                    j['status'] == 'failed'
                        ? FilledButton(
                            onPressed: () async {
                              final ok = await runAction(context, () => api.post('/staff/kitchen/jobs/${j['id']}/retry'),
                                  'Job sent back to the robot');
                              if (ok) await reload();
                            },
                            child: const Text('Retry'),
                          )
                        : const SizedBox.shrink(),
                  ],
              ],
            ),
        ]);
      },
    );
  }

  static String _shortId(Object? id) {
    final s = '${id ?? ''}';
    return s.length >= 10 ? s.substring(4, 10) : s;
  }
}

// ---------------------------------------------------------------- sold out

typedef StockData = ({List<Map<String, dynamic>> ingredients, List<Map<String, dynamic>> items});

class StockView extends StatelessWidget {
  const StockView({super.key, required this.refresh});
  final Listenable refresh;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return AsyncView<StockData>(
      refresh: refresh,
      load: () async {
        final r = await Future.wait([api.get('/staff/ingredients'), api.get('/staff/menu-items')]);
        return (ingredients: asMapList(r[0]), items: asMapList(r[1]));
      },
      builder: (context, data, reload) {
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final i in data.ingredients) {
          groups.putIfAbsent('${i['group'] ?? 'other'}', () => []).add(i);
        }
        final panels = <Widget>[
          Panel(
            title: 'Dishes',
            child: Column(children: [
              for (final i in data.items)
                AvailabilitySwitch(
                  key: Key('dish-${i['id']}'),
                  name: '${i['name']}',
                  initial: i['is_available'] == true,
                  save: (v) => api.patch('/staff/menu-items/${i['id']}/availability', {'is_available': v}),
                  onMessage: (v) => '${i['name']} is ${v ? 'back on' : 'sold out'}',
                ),
            ]),
          ),
          for (final g in groups.entries)
            Panel(
              title: g.key.replaceAll('_', ' '),
              child: Column(children: [
                for (final i in g.value)
                  AvailabilitySwitch(
                    key: Key('ing-${i['id']}'),
                    name: '${i['name']}',
                    initial: i['is_available'] == true,
                    save: (v) => api.patch('/staff/ingredients/${i['id']}/availability', {'is_available': v}),
                    onMessage: (v) => '${i['name']} is ${v ? 'back on' : 'sold out'}',
                  ),
              ]),
            ),
        ];
        return ListView(children: [
          const Muted('Switching something off hides it in the app straight away and blocks it at checkout.'),
          const SizedBox(height: 12),
          TwoColumns(children: panels),
        ]);
      },
    );
  }
}

/// A row with a name and an on/off switch that saves immediately and rolls back on failure.
class AvailabilitySwitch extends StatefulWidget {
  const AvailabilitySwitch({super.key, required this.name, required this.initial, required this.save,
      required this.onMessage, this.trailingLabel});
  final String name;
  final bool initial;
  final Future<dynamic> Function(bool value) save;
  final String Function(bool value) onMessage;
  final String? trailingLabel;

  @override
  State<AvailabilitySwitch> createState() => _AvailabilitySwitchState();
}

class _AvailabilitySwitchState extends State<AvailabilitySwitch> {
  late bool _on = widget.initial;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant AvailabilitySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.initial != widget.initial) _on = widget.initial;
  }

  Future<void> _toggle(bool v) async {
    setState(() {
      _on = v;
      _saving = true;
    });
    final ok = await runAction(context, () async => widget.save(v), widget.onMessage(v));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _on = !v;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RK.lineSoft))),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(widget.name)),
        Switch(value: _on, onChanged: _saving ? null : _toggle),
      ]),
    );
  }
}

/// Lays children out in two columns on wide screens and one on narrow ones.
class TwoColumns extends StatelessWidget {
  const TwoColumns({super.key, required this.children, this.gap = 14});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 760;
      final w = two ? (c.maxWidth - gap) / 2 : c.maxWidth;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}
