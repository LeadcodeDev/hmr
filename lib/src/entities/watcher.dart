import 'dart:async';
import 'dart:io';

import 'package:hmr/src/contracts/hmr.dart';

final class Watcher implements WatcherContract {
  StreamSubscription<FileSystemEvent>? _subscription;

  @override
  late final List<MiddlewareWatcher> middlewares;

  @override
  final FutureOr Function()? onStart;

  @override
  final FutureOr Function(File)? onFileModify;

  @override
  final FutureOr Function(File)? onFileCreate;

  @override
  final FutureOr Function(File)? onFileDelete;

  @override
  final FutureOr Function(File)? onFileMove;

  @override
  final FutureOr Function(int type, File)? onFileChange;

  Watcher({
    List<MiddlewareWatcher>? middlewares,
    this.onStart,
    this.onFileChange,
    this.onFileCreate,
    this.onFileDelete,
    this.onFileMove,
    this.onFileModify,
  }) : middlewares = middlewares ?? [];

  @override
  void watch() {
    onStart?.call();

    _subscription = Directory.current.watch(recursive: true).listen((event) {
      int currentMiddleware = 0;

      void executeNext() {
        if (currentMiddleware < middlewares.length) {
          final middleware = middlewares[currentMiddleware];
          currentMiddleware++;
          middleware.handle(event, executeNext);
        } else {
          switch (event.type) {
            case FileSystemEvent.modify:
              onFileModify?.call(File(event.path));
            case FileSystemEvent.create:
              onFileCreate?.call(File(event.path));
            case FileSystemEvent.delete:
              onFileDelete?.call(File(event.path));
            case FileSystemEvent.move:
              onFileMove?.call(File(event.path));
            default:
              () => throw 'Unknown event type: ${event.type}';
          }

          onFileChange?.call(event.type, File(event.path));
        }
      }

      executeNext();
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
