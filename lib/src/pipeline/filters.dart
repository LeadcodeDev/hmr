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
