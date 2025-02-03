import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';

final class IncludeMiddleware implements MiddlewareWatcher {
  final List<Glob> _globs;

  IncludeMiddleware(this._globs);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    final hasMatch = _globs.any((glob) => glob.matches(event.path));
    if (hasMatch) {
      next();
    }
  }
}
