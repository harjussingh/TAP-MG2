import 'package:flutter_test/flutter_test.dart';
import 'package:robokitchen_panel/format.dart';

void main() {
  test('dates without a zone are read as UTC', () {
    expect(parseTime('2026-10-07T04:00:00'), DateTime.utc(2026, 10, 7, 4).toLocal());
    expect(parseTime('2026-10-07T04:00:00Z'), DateTime.utc(2026, 10, 7, 4).toLocal());
    expect(parseTime(null), isNull);
  });
}
