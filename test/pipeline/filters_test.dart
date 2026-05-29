import 'package:glob/glob.dart';
import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/pipeline/filters.dart';
import 'package:test/test.dart';

FsEvent _e(String path) => FsModified(path, DateTime.now());

void main() {
  group('ignoreSegment', () {
    test('rejects paths with a forbidden segment', () {
      final f = ignoreSegment(const ['.git', '.dart_tool']);
      expect(f(_e('/repo/.git/HEAD')), isFalse);
      expect(f(_e('/repo/.dart_tool/pkg.json')), isFalse);
    });

    test('accepts paths where the token is only a substring', () {
      final f = ignoreSegment(const ['.git']);
      expect(f(_e('/repo/.gitignore-test/x.dart')), isTrue);
    });

    test('accepts normal paths', () {
      final f = ignoreSegment(const ['.git']);
      expect(f(_e('/repo/lib/main.dart')), isTrue);
    });
  });

  group('includeGlobs', () {
    test('accepts matched paths', () {
      final f = includeGlobs([Glob('**.dart')]);
      expect(f(_e('lib/x.dart')), isTrue);
    });

    test('rejects unmatched paths', () {
      final f = includeGlobs([Glob('**.dart')]);
      expect(f(_e('lib/x.txt')), isFalse);
    });
  });

  group('excludeGlobs', () {
    test('rejects matched paths', () {
      final f = excludeGlobs([Glob('test/**')]);
      expect(f(_e('test/x.dart')), isFalse);
    });

    test('accepts unmatched paths', () {
      final f = excludeGlobs([Glob('test/**')]);
      expect(f(_e('lib/x.dart')), isTrue);
    });
  });

  group('defaultExcludes', () {
    final f = excludeGlobs(defaultExcludes);

    test('rejects tests, build and IDE config directories', () {
      expect(f(_e('test/foo_test.dart')), isFalse);
      expect(f(_e('build/app.snapshot')), isFalse);
      expect(f(_e('doc/api.md')), isFalse);
      expect(f(_e('docs/api.md')), isFalse);
      expect(f(_e('.git/HEAD')), isFalse);
      expect(f(_e('.idea/workspace.xml')), isFalse);
      expect(f(_e('.vscode/settings.json')), isFalse);
    });

    test('rejects editor temp and backup artefacts', () {
      expect(f(_e('lib/.#main.dart')), isFalse);
      expect(f(_e('lib/main.dart~')), isFalse);
      expect(f(_e('lib/.main.dart.swp')), isFalse);
      expect(f(_e('lib/.main.dart.swo')), isFalse);
      expect(f(_e('lib/___jb_tmp___main.dart')), isFalse);
      expect(f(_e('lib/main.dart.tmp')), isFalse);
      expect(f(_e('lib/main.dart.bak')), isFalse);
      expect(f(_e('lib/.DS_Store')), isFalse);
    });

    test('accepts ordinary source files', () {
      expect(f(_e('lib/main.dart')), isTrue);
      expect(f(_e('lib/events/on_ready.dart')), isTrue);
      expect(f(_e('bin/app.dart')), isTrue);
    });
  });
}
