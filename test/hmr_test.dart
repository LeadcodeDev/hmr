import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Config', () {
    test('should parse valid YAML configuration', () {
      final yaml = YamlMap.wrap({
        'entrypoint': 'lib/main.dart',
        'includes': ['**/*.dart', '**/*.txt'],
        'excludes': ['**/test/**'],
      });

      final config = Config.of(yaml);

      expect(config.entrypoint, equals('lib/main.dart'));
      expect(config.includes, hasLength(2));
      expect(config.excludes, hasLength(1));
    });

    test('should handle missing values with defaults', () {
      final yaml = YamlMap.wrap({});
      final config = Config.of(yaml);

      expect(config.entrypoint, isNull);
      expect(config.includes, isNull);
      expect(config.excludes, isNull);
    });
  });

  group('Runner', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('should initialize temporary files', () async {
      final runner = Runner(
        entrypoint: File(path.join('test', 'mocks', 'app.dart')),
        tempDirectory: tempDir,
      );

      await runner.run();

      expect(runner.tempPath.existsSync(), isTrue);
      expect(runner.dillFile.existsSync(), isTrue); // Not created until compilation
    });
  });

  group('Watcher', () {
    late Directory testDir;
    Watcher? watcher;

    setUp(() async {
      testDir = Directory(path.join(Directory.current.path, 'test_temp'));
      await testDir.create(recursive: true);
    });

    tearDown(() async {
      await testDir.delete(recursive: true);
      watcher?.dispose(); // Dispose le watcher après chaque test
    });

    test('should detect file modifications', () async {
      final completer = Completer<void>();
      watcher = Watcher(
        includes: [Glob('${testDir.path}/**')],
        onFileModify: (file) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      watcher?.watch();

      final file = File(path.join(testDir.path, 'test.txt'));
      await file.create();

      await Future.delayed(const Duration(milliseconds: 100));
      await file.writeAsString('modified');

      await completer.future.timeout(const Duration(seconds: 2));
      expect(completer.isCompleted, isTrue);
    });
  });

  group('Integration', () {
    test('should initialize with default config', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      final runner = Runner(
        entrypoint: File('bin/test_app.dart'),
        tempDirectory: tempDir,
      );

      expect(() => runner.run(), returnsNormally);
    });
  });
}
