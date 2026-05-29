import 'dart:io';
import 'dart:isolate';

import 'package:yaml/yaml.dart';

Future<String>? _cached;

/// Returns the hmr package version by reading its own `pubspec.yaml`.
/// The result is cached for the lifetime of the isolate.
Future<String> resolveHmrVersion() {
  return _cached ??= _read();
}

Future<String> _read() async {
  final libUri = await Isolate.resolvePackageUri(Uri.parse('package:hmr/'));
  if (libUri == null) return 'unknown';
  final pubspec = File.fromUri(libUri.resolve('../pubspec.yaml'));
  final yaml = loadYaml(await pubspec.readAsString());
  return (yaml is Map && yaml['version'] is String)
      ? yaml['version'] as String
      : 'unknown';
}
