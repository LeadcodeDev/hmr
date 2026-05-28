import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

final class ConfigError implements Exception {
  final String field;
  final String message;
  ConfigError(this.field, this.message);
  @override
  String toString() => 'ConfigError($field): $message';
}

final class Config {
  final String? entrypoint;
  final int? debounce;
  final List<Glob>? includes;
  final List<Glob>? excludes;

  Config({this.entrypoint, this.debounce, this.includes, this.excludes});

  factory Config.of(YamlMap payload) {
    String? entrypoint;
    if (payload.containsKey('entrypoint')) {
      final raw = payload['entrypoint'];
      if (raw is! String) {
        throw ConfigError('entrypoint', 'expected String, got ${raw.runtimeType}');
      }
      entrypoint = raw;
    }

    int? debounce;
    if (payload.containsKey('debounce')) {
      final raw = payload['debounce'];
      if (raw is! int) {
        throw ConfigError('debounce', 'expected int (milliseconds), got ${raw.runtimeType}');
      }
      if (raw < 0) {
        throw ConfigError('debounce', 'must be >= 0, got $raw');
      }
      debounce = raw;
    }

    return Config(
      entrypoint: entrypoint,
      debounce: debounce,
      includes: _globList(payload, 'includes'),
      excludes: _globList(payload, 'excludes'),
    );
  }

  static List<Glob>? _globList(YamlMap payload, String field) {
    if (!payload.containsKey(field)) return null;
    final raw = payload[field];
    if (raw is! List) {
      throw ConfigError(field, 'expected list of glob strings, got ${raw.runtimeType}');
    }
    return raw.map((e) {
      if (e is! String) {
        throw ConfigError(field, 'list elements must be strings, got ${e.runtimeType}');
      }
      return Glob(e);
    }).toList();
  }
}
