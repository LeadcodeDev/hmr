import 'dart:async';
import 'dart:io';

import 'package:hmr/hmr.dart';

/// Trailing-edge debounce: emits the last received event after [_delay]
/// of silence.
final class DebounceMiddleware implements MiddlewareWatcher {
  final Duration _delay;
  Timer? _timer;
  NextFn? _pendingNext;

  DebounceMiddleware(this._delay);

  @override
  void handle(FileSystemEvent event, NextFn next) {
    _pendingNext = next;
    _timer?.cancel();
    _timer = Timer(_delay, _fire);
  }

  void _fire() {
    final next = _pendingNext;
    _pendingNext = null;
    _timer = null;
    next?.call();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingNext = null;
  }
}
