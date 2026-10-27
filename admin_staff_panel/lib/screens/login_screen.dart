import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';

enum Station { staff, manager }

class _Demo {
  const _Demo(this.title, this.email, this.password);
  final String title, email, password;
}

const _demo = {
  Station.staff: _Demo('Kitchen staff sign in', 'staff@robokitchen.com', 'Staff12345'),
  Station.manager: _Demo('Manager sign in', 'admin@robokitchen.com', 'Admin12345'),
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Station? _station;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  String _service = '—';
  String _tables = '—';

  @override
  void initState() {
    super.initState();
    _loadPublicInfo();
  }

  Future<void> _loadPublicInfo() async {
    final api = AppScope.read(context).api;
    final ok = await api.health();
    if (!mounted) return;
    setState(() => _service = ok ? 'online' : 'offline');
    try {
      final n = await api.get('/tables/numbers');
      if (mounted && n is List) setState(() => _tables = n.isEmpty ? '—' : '${n.length}');
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _pick(Station s) {
    final d = _demo[s]!;
    setState(() {
      _station = s;
      _email.text = d.email;
      _password.text = d.password;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context)
          .signIn(_email.text, _password.text, asManager: _station == Station.manager);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 860;
        final brand = _Brand(service: _service, tables: _tables);
        final action = Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _station == null ? _choice() : _form(),
          ),
        );
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: brand),
            SizedBox(width: 480, child: Center(child: SingleChildScrollView(child: action))),
          ]);
        }
        return SingleChildScrollView(child: Column(children: [brand, action]));
      }),
    );
  }

  Widget _choice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Who is signing in?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Choose your station. You can switch later by signing out.', style: TextStyle(color: RK.muted)),
        const SizedBox(height: 18),
        _ChoiceTile(
          key: const Key('choose-staff'),
          icon: Icons.view_agenda_outlined,
          accent: RK.cooking,
          title: 'Kitchen staff',
          subtitle: 'Live order board, robot queue, mark items sold out.',
          onTap: () => _pick(Station.staff),
        ),
        const SizedBox(height: 10),
        _ChoiceTile(
          key: const Key('choose-manager'),
          icon: Icons.dashboard_outlined,
          accent: RK.queued,
          title: 'Manager',
          subtitle: 'Takings, orders and refunds, menu, tables, reviews, team, settings.',
          onTap: () => _pick(Station.manager),
        ),
      ],
    );
  }

  Widget _form() {
    final d = _demo[_station]!;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : () => setState(() => _station = null),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Choose a different station'),
              ),
            ),
            const SizedBox(height: 6),
            Text(d.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('email'),
              controller: _email,
              decoration: const InputDecoration(labelText: 'Work email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email address' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('password'),
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('login-error'), style: const TextStyle(color: RK.alert)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton(
                key: const Key('sign-in'),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Signing in…' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 14),
            Text('Demo login: ${d.email} / ${d.password}', style: const TextStyle(color: RK.dim, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.service, required this.tables});
  final String service, tables;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RK.rail,
      padding: const EdgeInsets.fromLTRB(36, 48, 36, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: const BoxDecoration(color: RK.cooking, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            const Text('ROBOKITCHEN', style: TextStyle(letterSpacing: 2.5, color: RK.muted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 26),
          const Text('Service panel', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.05)),
          const SizedBox(height: 10),
          const Text('Run the pass, the robot and the floor from one screen.',
              style: TextStyle(color: RK.muted, fontSize: 16)),
          const SizedBox(height: 30),
          Wrap(spacing: 28, runSpacing: 14, children: [
            _Stat(value: service, label: 'service', color: service == 'online' ? RK.ready : RK.alert),
            _Stat(value: tables, label: 'tables in service'),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color = RK.text});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(color: RK.muted, fontSize: 12.5)),
      ]);
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({super.key, required this.icon, required this.accent, required this.title,
      required this.subtitle, required this.onTap});
  final IconData icon;
  final Color accent;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RK.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: RK.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: RK.muted, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: RK.dim),
          ]),
        ),
      ),
    );
  }
}
