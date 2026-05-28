import 'package:impl/handler_registry.dart';
import 'package:test/test.dart';

void main() {
  group('HandlerRegistry', () {
    test('invoke calls the registered handler', () {
      var called = false;
      final r = HandlerRegistry();
      r.register('test', () => called = true);
      r.invoke('test');
      expect(called, isTrue);
    });

    test('invoke with unknown name does nothing', () {
      expect(() => HandlerRegistry().invoke('unknown'), returnsNormally);
    });

    test('names returns registered handler names', () {
      final r = HandlerRegistry()
        ..register('a', () {})
        ..register('b', () {});
      expect(r.names, containsAll(['a', 'b']));
    });

    test('re-registering replaces the previous handler', () {
      var count = 0;
      final r = HandlerRegistry();
      r.register('x', () => count++);
      r.register('x', () => count += 10);
      r.invoke('x');
      expect(count, 10);
    });
  });
}
