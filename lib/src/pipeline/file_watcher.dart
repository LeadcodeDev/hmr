import 'dart:async';

import 'package:watcher/watcher.dart';

import '../domain/events.dart';

class FileWatcher {
  final DirectoryWatcher _watcher;
  final _controller = StreamController<FsEvent>.broadcast();
  late final StreamSubscription<WatchEvent> _sub;

  FileWatcher(String path) : _watcher = DirectoryWatcher(path) {
    _sub = _watcher.events.listen((evt) {
      final at = DateTime.now();
      final event = switch (evt.type) {
        ChangeType.ADD => FsCreated(evt.path, at),
        ChangeType.MODIFY => FsModified(evt.path, at),
        ChangeType.REMOVE => FsDeleted(evt.path, at),
        _ => FsModified(evt.path, at),
      };
      _controller.add(event);
    }, onError: _controller.addError);
  }

  Stream<FsEvent> get stream => _controller.stream;

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
