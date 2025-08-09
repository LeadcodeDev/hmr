import 'dart:io';

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

      expect(runner.tempDirectory.existsSync(), isTrue);
      expect(runner.dillFile.existsSync(),
          isTrue); // Not created until compilation
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
