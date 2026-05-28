import 'dart:io';

import 'package:hmr/hmr.dart';
import 'package:test/test.dart';

FileSystemEvent _event(String path) => FileSystemModifyEvent(path, false, false);

void main() {
  group('IgnoreMiddleware', () {
    test('ignores a path containing a forbidden segment', () {
      final mw = IgnoreMiddleware(const ['.git', '.dart_tool']);
      var called = false;
      mw.handle(_event('/repo/.git/HEAD'), () => called = true);
      expect(called, isFalse);
    });

    test('does NOT ignore when the token is only a substring of a segment', () {
      final mw = IgnoreMiddleware(const ['.git']);
      var called = false;
      mw.handle(_event('/repo/.gitignore-test/main.dart'), () => called = true);
      expect(called, isTrue,
          reason: '.gitignore-test is not the .git segment');
    });

    test('passes paths with no forbidden segment', () {
      final mw = IgnoreMiddleware(const ['.git']);
      var called = false;
      mw.handle(_event('/repo/lib/foo.dart'), () => called = true);
      expect(called, isTrue);
    });

    test('ignores nested forbidden segment', () {
      final mw = IgnoreMiddleware(const ['.dart_tool']);
      var called = false;
      mw.handle(_event('/repo/sub/.dart_tool/package_config.json'), () => called = true);
      expect(called, isFalse);
    });
  });
}
