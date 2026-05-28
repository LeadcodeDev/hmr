import 'dart:io';

import 'package:hmr/src/domain/entrypoint_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hmr_resolver_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<File> touch(String relative) async {
    final f = File(p.join(root.path, relative));
    await f.create(recursive: true);
    await f.writeAsString('void main() {}\n');
    return f;
  }

  group('EntrypointResolver', () {
    test('CLI argument takes priority over everything', () async {
      await touch('bin/main.dart');
      await touch('bin/my_pkg.dart');
      await touch('bin/custom.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      final f = r.resolve(
        cliArg: 'bin/custom.dart',
        configEntrypoint: 'bin/my_pkg.dart',
      );
      expect(p.basename(f.path), 'custom.dart');
    });

    test('absolute CLI argument is returned verbatim', () async {
      final abs = (await touch('bin/abs.dart')).path;
      final r = EntrypointResolver(projectRoot: root, packageName: null);
      expect(r.resolve(cliArg: abs).path, abs);
    });

    test('config entrypoint takes priority over conventions', () async {
      await touch('bin/main.dart');
      await touch('bin/my_pkg.dart');
      await touch('bin/from_config.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      final f = r.resolve(configEntrypoint: 'bin/from_config.dart');
      expect(p.basename(f.path), 'from_config.dart');
    });

    test('falls back to bin/<package>.dart when config absent', () async {
      await touch('bin/main.dart');
      await touch('bin/my_pkg.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      final f = r.resolve();
      expect(p.basename(f.path), 'my_pkg.dart');
    });

    test('falls back to bin/main.dart when bin/<package>.dart missing',
        () async {
      await touch('bin/main.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      final f = r.resolve();
      expect(p.basename(f.path), 'main.dart');
    });

    test('falls back to bin/main.dart when packageName is null', () async {
      await touch('bin/main.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: null);
      final f = r.resolve();
      expect(p.basename(f.path), 'main.dart');
    });

    test('throws EntrypointResolutionError when nothing exists', () async {
      final r = EntrypointResolver(projectRoot: root, packageName: 'absent');
      expect(
        () => r.resolve(),
        throwsA(
          isA<EntrypointResolutionError>()
              .having((e) => e.candidates, 'candidates',
                  containsAll(['bin/absent.dart', 'bin/main.dart']))
              .having((e) => e.toString(), 'toString',
                  contains('No Dart entrypoint found')),
        ),
      );
    });

    test('config entrypoint absence falls through to convention', () async {
      await touch('bin/my_pkg.dart');

      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      final f = r.resolve(configEntrypoint: 'bin/missing.dart');
      expect(p.basename(f.path), 'my_pkg.dart');
    });

    test('error message lists every candidate checked', () async {
      final r = EntrypointResolver(projectRoot: root, packageName: 'my_pkg');
      try {
        r.resolve(configEntrypoint: 'bin/configured.dart');
        fail('Expected throw');
      } on EntrypointResolutionError catch (e) {
        expect(e.candidates, [
          'bin/configured.dart',
          'bin/my_pkg.dart',
          'bin/main.dart',
        ]);
      }
    });
  });
}
