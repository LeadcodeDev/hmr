import 'dart:io';

import 'package:path/path.dart' as p;

class EntrypointResolutionError implements Exception {
  final String message;
  final List<String> candidates;
  EntrypointResolutionError(this.message, this.candidates);

  @override
  String toString() {
    final lines = StringBuffer()..writeln(message);
    if (candidates.isNotEmpty) {
      lines.writeln('Checked:');
      for (final c in candidates) {
        lines.writeln('  - $c');
      }
    }
    return lines.toString().trimRight();
  }
}

/// Resolves which `.dart` file the HMR child process should run.
///
/// Priority (first match wins):
///   1. `cliArg`           — `hmr bin/server.dart`
///   2. `configEntrypoint` — pubspec `hmr.entrypoint:`
///   3. `bin/<packageName>.dart` (Pub convention)
///   4. `bin/main.dart` (fallback)
///
/// Returns the resolved [File] (existence verified for resolutions 2-4 only;
/// CLI argument is trusted to the caller and surfaced as-is if missing).
class EntrypointResolver {
  final Directory projectRoot;
  final String? packageName;

  EntrypointResolver({required this.projectRoot, required this.packageName});

  File resolve({String? cliArg, String? configEntrypoint}) {
    final checked = <String>[];

    if (cliArg != null && cliArg.isNotEmpty) {
      return File(_absolute(cliArg));
    }

    if (configEntrypoint != null && configEntrypoint.isNotEmpty) {
      final path = _absolute(configEntrypoint);
      checked.add(p.relative(path, from: projectRoot.path));
      if (File(path).existsSync()) return File(path);
    }

    if (packageName != null && packageName!.isNotEmpty) {
      final path = p.join(projectRoot.path, 'bin', '$packageName.dart');
      checked.add(p.relative(path, from: projectRoot.path));
      if (File(path).existsSync()) return File(path);
    }

    final fallback = p.join(projectRoot.path, 'bin', 'main.dart');
    checked.add(p.relative(fallback, from: projectRoot.path));
    if (File(fallback).existsSync()) return File(fallback);

    throw EntrypointResolutionError(
      'No Dart entrypoint found. Pass one explicitly: `hmr bin/server.dart`.',
      checked,
    );
  }

  String _absolute(String path) =>
      p.isAbsolute(path) ? path : p.join(projectRoot.path, path);
}
