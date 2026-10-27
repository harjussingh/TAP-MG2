/// Money and time formatting. Kept dependency-free (no intl) on purpose.
library;

String currencyCode = 'AUD';
String taxLabel = 'GST';

const _symbols = {'AUD': r'$', 'USD': r'$', 'NZD': r'$', 'CAD': r'$', 'SGD': r'$', 'EUR': '€', 'GBP': '£', 'INR': '₹'};

String money(Object? cents) {
  final c = cents is num ? cents.round() : 0;
  final negative = c < 0;
  final abs = c.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final frac = (abs % 100).toString().padLeft(2, '0');
  final sym = _symbols[currencyCode] ?? '$currencyCode ';
  return '${negative ? '-' : ''}$sym$whole.$frac';
}

DateTime? parseTime(Object? iso) {
  if (iso is! String || iso.isEmpty) return null;
  // The API sends UTC; values without an offset are treated as UTC too.
  final hasZone = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(iso);
  return DateTime.tryParse(hasZone ? iso : '${iso}Z')?.toLocal();
}

String two(int n) => n.toString().padLeft(2, '0');

String clock(Object? iso) {
  final t = parseTime(iso);
  return t == null ? '—' : '${two(t.hour)}:${two(t.minute)}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dayTime(Object? iso) {
  final t = parseTime(iso);
  return t == null ? '—' : '${two(t.day)} ${_months[t.month - 1]} ${two(t.hour)}:${two(t.minute)}';
}

int secondsSince(Object? iso, [DateTime? now]) {
  final t = parseTime(iso);
  if (t == null) return 0;
  final s = (now ?? DateTime.now()).difference(t).inSeconds;
  return s < 0 ? 0 : s;
}

String mmss(int s) => '${two(s ~/ 60)}:${two(s % 60)}';

/// "pay_at_counter" -> "pay at counter"
String human(Object? v) => (v ?? '').toString().replaceAll('_', ' ');

String whereLabel(Map<String, dynamic> o) {
  final table = o['table'];
  if (table is Map && table['number'] != null) return 'Table ${table['number']}';
  return o['order_type'] == 'takeaway' ? 'Takeaway' : 'Dine in';
}
