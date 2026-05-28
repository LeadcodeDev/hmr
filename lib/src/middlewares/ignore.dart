import 'dart:io';

import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as p;

final class IgnoreMiddleware implements MiddlewareWatcher {
  final List<String> _matches;

  IgnoreMiddleware(this._matches);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    final segments = p.split(event.path);
    final isIgnored = segments.any(_matches.contains);
    if (!isIgnored) next();
  }
}
