import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../domain/events.dart';

class FileWatcher {
  final DirectoryWatcher _watcher;
  final String _root;
  final _controller = StreamController<FsEvent>.broadcast();
  late final StreamSubscription<WatchEvent> _sub;

  FileWatcher(String path)
      : _watcher = DirectoryWatcher(path),
        _root = p.normalize(p.absolute(path)) {
    _sub = _watcher.events.listen((evt) {
      final at = DateTime.now();
      // Emit paths relative to the watched root so glob patterns like
      // **/*.dart (relative) match correctly — absolute paths would not.
      final rel = p.relative(evt.path, from: _root);
final event = switch (evt.type) {
        ChangeType.ADD => FsCreated(rel, at),
        ChangeType.MODIFY => FsModified(rel, at),
        ChangeType.REMOVE => FsDeleted(rel, at),
        _ => FsModified(rel, at),
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
