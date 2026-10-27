import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';

void toast(BuildContext context, String message, {bool bad = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      // Start right of the navigation rail so the toast never covers the rail's buttons.
      margin: const EdgeInsets.fromLTRB(76, 0, 16, 16),
      backgroundColor: bad ? const Color(0xFF4A1F1C) : RK.surface2,
    ));
}

/// Runs an action, shows a toast on success, and a readable error toast on failure.
/// Returns true when the action succeeded.
Future<bool> runAction(BuildContext context, Future<void> Function() action, [String? ok]) async {
  try {
    await action();
    if (ok != null && context.mounted) toast(context, ok);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, bad: true);
  } catch (e) {
    if (context.mounted) toast(context, 'Something went wrong: $e', bad: true);
  }
  return false;
}

/// Text prompt dialog; returns null when cancelled.
Future<String?> askText(BuildContext context, String title, {String initial = '', String confirm = 'OK'}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextPrompt(title: title, initial: initial, confirm: confirm),
  );
}

/// Owns its controller, so it is disposed only after the closing animation has finished.
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.initial, required this.confirm});
  final String title, initial, confirm;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_ctrl.text), child: Text(widget.confirm)),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16), this.accent});
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    // Rounded borders must be one colour, so the accent is an inner stripe clipped by the rounded outline.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RK.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RK.line),
      ),
      child: Container(
        decoration: accent == null ? null : BoxDecoration(border: Border(left: BorderSide(color: accent!, width: 3))),
        padding: padding,
        child: _content(),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
        child,
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = RK.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label ?? human(status), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = RK.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(3)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11.5)),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(border: Border.all(color: RK.lineSoft), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: const TextStyle(color: RK.muted), textAlign: TextAlign.center),
      );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: RK.muted, fontSize: size));
}

/// Loads data with [load], shows a spinner, errors with a retry button, then [builder].
/// Call [AsyncViewState.reload] through a GlobalKey (or let the shell's refresh do it).
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.refresh});
  final Future<T> Function() load;

  /// Reloads silently whenever this fires (refresh button, live events, timers).
  final Listenable? refresh;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(reload);
    reload();
  }

  @override
  void didUpdateWidget(covariant AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(reload);
      widget.refresh?.addListener(reload);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final gen = ++_generation;
    if (_data == null) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted || gen != _generation) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(accent: RK.alert, child: Text('Could not refresh: $_error')),
            ),
          Expanded(child: widget.builder(context, data, reload)),
        ],
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$_error', textAlign: TextAlign.center, style: const TextStyle(color: RK.alert)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: reload, child: const Text('Try again')),
      ]),
    );
  }
}

/// Simple data table with a header row, styled like the HTML panel. Scrolls sideways on narrow screens.
class SimpleTable extends StatelessWidget {
  const SimpleTable({super.key, required this.columns, required this.rows, this.numeric = const {}});
  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int> numeric;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 44,
            dataRowMaxHeight: double.infinity,
            horizontalMargin: 12,
            columnSpacing: 22,
            dividerThickness: 0.6,
            headingTextStyle: const TextStyle(color: RK.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            border: const TableBorder(horizontalInside: BorderSide(color: RK.lineSoft)),
            columns: [
              for (var i = 0; i < columns.length; i++) DataColumn(label: Text(columns[i]), numeric: numeric.contains(i)),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [
                  for (final w in r) DataCell(Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: w)),
                ]),
            ],
          ),
        ),
      );
    });
  }
}
