import 'dart:io';

import 'package:hmr/hmr.dart';

final class DebounceMiddleware implements MiddlewareWatcher {
  final Duration _debounce;
  DateTime _dateTime;

  DebounceMiddleware(this._debounce, this._dateTime);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    if (!(DateTime.now().difference(_dateTime) < _debounce)) {
      next();
      _dateTime = DateTime.now();
    }
  }
}
