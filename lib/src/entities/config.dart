import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

/// The configuration of the HMR.
final class Config {
  final String? entrypoint;
  final int? debounce;
  final List<Glob>? includes;
  final List<Glob>? excludes;

  Config({
    this.entrypoint,
    this.debounce,
    this.includes,
    this.excludes,
  });

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
