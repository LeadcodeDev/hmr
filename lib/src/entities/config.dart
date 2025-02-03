import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

/// The configuration of the HMR.
final class Config {
  /// The entrypoint of the application.
  final String? entrypoint;

  /// The debounce time in milliseconds.
  final int? debounce;

  /// The list of includes.
  final List<Glob>? includes;

  /// The list of excludes.
  final List<Glob>? excludes;

  Config({
    this.entrypoint,
    this.debounce,
    this.includes,
    this.excludes,
  });

  /// Create a new instance of [Config] from a [YamlMap] payload.
  factory Config.of(YamlMap payload) {
    List<Glob>? parseGlobList(List? list) {
      if (list == null) return null;
      return list.map((e) => Glob(e)).toList();
    }

    return Config(
      entrypoint: payload['entrypoint'],
      debounce: payload['debounce'],
      includes: parseGlobList(payload['includes']),
      excludes: parseGlobList(payload['excludes']),
    );
  }
}
