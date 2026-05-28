import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:hmr/src/pipeline/debounce.dart';
import 'package:test/test.dart';

void main() {
  group('debounceTrailing', () {
    test('emits only the trailing event of a burst', () {
      fakeAsync((async) {
        final src = StreamController<int>();
        final out = <int>[];
        src.stream
            .transform(debounceTrailing(const Duration(milliseconds: 100)))
            .listen(out.add);

        for (var i = 0; i < 5; i++) {
          src.add(i);
          async.elapse(const Duration(milliseconds: 20));
        }
        async.elapse(const Duration(milliseconds: 200));
        expect(out, [4]);
        src.close();
      });
    });

    test('two separate bursts emit two values', () {
      fakeAsync((async) {
        final src = StreamController<int>();
        final out = <int>[];
        src.stream
            .transform(debounceTrailing(const Duration(milliseconds: 100)))
            .listen(out.add);

        src.add(1);
        async.elapse(const Duration(milliseconds: 200));
        src.add(2);
        async.elapse(const Duration(milliseconds: 200));
        expect(out, [1, 2]);
        src.close();
      });
    });

    test('on source close, flushes the pending value', () async {
      final src = StreamController<int>();
      final received = <int>[];
      final done = src.stream
          .transform(debounceTrailing<int>(const Duration(seconds: 5)))
          .listen(received.add)
          .asFuture<void>();
      src.add(99);
      await src.close();
      await done;
      expect(received, [99]);
    });

    test('on source close with no pending value, closes cleanly', () async {
      final src = StreamController<int>();
      final received = <int>[];
      final done = src.stream
          .transform(debounceTrailing<int>(const Duration(seconds: 5)))
          .listen(received.add)
          .asFuture<void>();
      await src.close();
      await done;
      expect(received, isEmpty);
    });
  });
}
