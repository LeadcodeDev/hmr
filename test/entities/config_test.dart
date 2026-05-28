import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Config.of validation', () {
    test('parses a valid payload with all fields', () {
      final yaml = YamlMap.wrap({
        'entrypoint': 'lib/main.dart',
        'debounce': 50,
        'includes': ['**/*.dart', '**/*.txt'],
        'excludes': ['test/**'],
      });
      final c = Config.of(yaml);
      expect(c.entrypoint, 'lib/main.dart');
      expect(c.debounce, 50);
      expect(c.includes, hasLength(2));
      expect(c.excludes, hasLength(1));
    });

    test('all-optional empty payload yields all-null fields', () {
      final c = Config.of(YamlMap.wrap({}));
      expect(c.entrypoint, isNull);
      expect(c.debounce, isNull);
      expect(c.includes, isNull);
      expect(c.excludes, isNull);
    });

    test('debounce = 0 is accepted', () {
      expect(Config.of(YamlMap.wrap({'debounce': 0})).debounce, 0);
    });

    test('rejects non-string entrypoint', () {
      final yaml = YamlMap.wrap({'entrypoint': 42});
      expect(() => Config.of(yaml),
          throwsA(isA<ConfigError>()
              .having((e) => e.field, 'field', 'entrypoint')));
    });

    test('rejects non-int debounce', () {
      final yaml = YamlMap.wrap({'debounce': '50ms'});
      expect(() => Config.of(yaml),
          throwsA(isA<ConfigError>()
              .having((e) => e.field, 'field', 'debounce')));
    });

    test('rejects negative debounce', () {
      final yaml = YamlMap.wrap({'debounce': -1});
      expect(() => Config.of(yaml),
          throwsA(isA<ConfigError>()
              .having((e) => e.field, 'field', 'debounce')));
    });

    test('rejects non-list includes', () {
      final yaml = YamlMap.wrap({'includes': 'oops'});
      expect(() => Config.of(yaml), throwsA(isA<ConfigError>()));
    });

    test('rejects list with non-string element in excludes', () {
      final yaml = YamlMap.wrap({'excludes': ['valid', 42]});
      expect(() => Config.of(yaml), throwsA(isA<ConfigError>()));
    });
  });
}
