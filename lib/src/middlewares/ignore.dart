import 'dart:io';

import 'package:hmr/hmr.dart';

final class IgnoreMiddleware implements MiddlewareWatcher {
  final List<String> _matches;

  IgnoreMiddleware(this._matches);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    final ignoredFiles = _matches.any((match) => event.path.contains(match));
    if (!ignoredFiles) {
      next();
    }
  }
}
