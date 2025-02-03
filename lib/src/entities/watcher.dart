import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/src/contracts/hmr.dart';

final class Watcher implements WatcherContract {
  StreamSubscription<FileSystemEvent>? _subscription;

  DateTime? _dateTime = DateTime.now();

  @override
  final List<Glob> includes;

  @override
  final List<Glob> excludes;

  @override
  final int debounce;

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
    this.excludes = const [],
    this.includes = const [],
    this.debounce = 5,
    this.onStart,
    this.onFileChange,
    this.onFileCreate,
    this.onFileDelete,
    this.onFileMove,
    this.onFileModify,
  });

  @override
  void watch() {
    onStart?.call();

    _subscription = Directory.current.watch(recursive: true).listen((event) {
      if (_dateTime case DateTime value
          when DateTime.now().difference(value) < Duration(milliseconds: debounce)) {
        return;
      }

      final ignoredFiles = event.path.endsWith('~') ||
          event.path.contains('.idea') ||
          event.path.contains('.git') ||
          event.path.contains('.dart_tool');

      if (ignoredFiles) {
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
        _dateTime = DateTime.now();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
