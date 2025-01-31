import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/src/contracts/hmr.dart';

final class Watcher implements WatcherContract {
  StreamSubscription<FileSystemEvent>? _subscription;

  final List<Glob> includes;
  final List<Glob> excludes;

  final FutureOr Function()? onStart;
  final FutureOr Function(File)? onFileModify;
  final FutureOr Function(File)? onFileCreate;
  final FutureOr Function(File)? onFileDelete;
  final FutureOr Function(File)? onFileMove;
  final FutureOr Function(int type, File)? onFileChange;

  Watcher({
    this.excludes = const [],
    this.includes = const [],
    this.onStart,
    this.onFileChange,
    this.onFileCreate,
    this.onFileDelete,
    this.onFileMove,
    this.onFileModify,
  });

  void watch() {
    onStart?.call();

    _subscription = Directory.current.watch(recursive: true).listen((event) {
      if (event.path.endsWith('~')) {
        return;
      }

      final hasExclude = excludes.any((glob) => glob.matches(event.path));
      if (hasExclude) {
        return;
      }

      final hasMatch = includes.any((glob) => glob.matches(event.path));
      if (hasMatch) {
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
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
