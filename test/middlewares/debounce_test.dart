import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:hmr/hmr.dart';
import 'package:test/test.dart';

FileSystemEvent _fakeEvent(String path) =>
    FileSystemModifyEvent(path, false, false);

void main() {
  group('DebounceMiddleware (trailing-edge)', () {
    test('a burst of 5 events emits exactly once after the quiet period', () {
      fakeAsync((async) {
        final mw = DebounceMiddleware(const Duration(milliseconds: 100));
        var emitted = 0;

        for (var i = 0; i < 5; i++) {
          mw.handle(_fakeEvent('a'), () => emitted++);
          async.elapse(const Duration(milliseconds: 20));
        }
        expect(emitted, 0, reason: 'no emission during burst');

        async.elapse(const Duration(milliseconds: 150));
        expect(emitted, 1, reason: 'exactly one trailing emission');
      });
    });

    test('two bursts spaced beyond the delay yield two emissions', () {
      fakeAsync((async) {
        final mw = DebounceMiddleware(const Duration(milliseconds: 100));
        var emitted = 0;

        mw.handle(_fakeEvent('a'), () => emitted++);
        async.elapse(const Duration(milliseconds: 200));
        expect(emitted, 1);

        mw.handle(_fakeEvent('b'), () => emitted++);
        async.elapse(const Duration(milliseconds: 200));
        expect(emitted, 2);
      });
    });

    test('dispose cancels a pending emission', () {
      fakeAsync((async) {
        final mw = DebounceMiddleware(const Duration(milliseconds: 100));
        var emitted = 0;
        mw.handle(_fakeEvent('a'), () => emitted++);
        mw.dispose();
        async.elapse(const Duration(milliseconds: 500));
        expect(emitted, 0);
      });
    });
  });
}
