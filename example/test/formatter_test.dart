import 'package:example/formatter.dart';
import 'package:test/test.dart';

void main() {
  group('format', () {
    test('returns count: N for zero', () {
      expect(format(0), 'count: 0');
    });

    test('returns count: N for a positive value', () {
      expect(format(42), 'count: 42');
    });
  });
}
