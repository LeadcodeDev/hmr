import 'package:impl/counter.dart';
import 'package:test/test.dart';

void main() {
  group('Counter', () {
    test('starts at zero', () {
      expect(Counter().value, 0);
    });

    test('increment increases value by one', () {
      final c = Counter();
      c.increment();
      expect(c.value, 1);
    });

    test('reset sets value back to zero', () {
      final c = Counter()..increment()..increment();
      c.reset();
      expect(c.value, 0);
    });
  });
}
