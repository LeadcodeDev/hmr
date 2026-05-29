import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../domain/events.dart';

typedef FsFilter = bool Function(FsEvent event);

FsFilter ignoreSegment(List<String> forbidden) {
  return (event) {
    final segments = p.split(event.path);
    return !segments.any(forbidden.contains);
  };
}

FsFilter includeGlobs(List<Glob> globs) {
  return (event) => globs.any((g) => g.matches(event.path));
}

FsFilter excludeGlobs(List<Glob> globs) {
  return (event) => !globs.any((g) => g.matches(event.path));
}

/// Default exclusion globs applied when the user does not set `hmr.excludes`
/// in `pubspec.yaml`. Covers tests, common build/doc directories, IDE config,
/// and editor temp/backup artefacts that would otherwise trigger spurious
/// reloads. `.dart_tool` is excluded separately and unconditionally — it
/// stays excluded even when the user provides a custom `excludes` list.
List<Glob> get defaultExcludes => [
      Glob('test/**'),
      Glob('build/**'),
      Glob('doc/**'),
      Glob('docs/**'),
      Glob('.git/**'),
      Glob('.idea/**'),
      Glob('.vscode/**'),
      Glob('**/.#*'),
      Glob('**/*~'),
      Glob('**/*.swp'),
      Glob('**/*.swo'),
      Glob('**/___jb_*___*'),
      Glob('**/*.tmp'),
      Glob('**/*.bak'),
      Glob('**/.DS_Store'),
    ];
