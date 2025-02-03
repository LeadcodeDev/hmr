import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';

final class ExcludeMiddleware implements MiddlewareWatcher {
  final List<Glob> _globs;

  ExcludeMiddleware(this._globs);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    final hasExclude = _globs.any((glob) => glob.matches(event.path));
    if (!hasExclude) {
      next();
    }
  }
}
