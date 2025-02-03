import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';

abstract interface class RunnerContract {
  /// The entrypoint file to run.
  File get entrypoint;

  /// The temporary directory to store the compiled files.
  Directory get tempDirectory;

  /// Run the entrypoint file.
  Future<void> run();

  /// Reload the entrypoint file.
  Future<void> reload();
}

abstract interface class WatcherContract {
  /// The list of files to exclude.
  List<Glob> get includes;

  /// The list of files to exclude.
  List<Glob> get excludes;

  /// The debounce time to wait before trigger the event.
  int get debounce;

  /// Emitted when the watcher is started.
  FutureOr Function()? get onStart;

  /// Emitted when the [File] is modified.
  FutureOr Function(File)? get onFileModify;

  /// Emitted when the [File] is created.
  FutureOr Function(File)? get onFileCreate;

  /// Emitted when the [File] is deleted.
  FutureOr Function(File)? get onFileDelete;

  /// Emitted when the [File] is moved.
  FutureOr Function(File)? get onFileMove;

  /// Emitted when the [File] is changed, this event trigger when the file is modified, created, deleted, or moved.
  FutureOr Function(int type, File)? get onFileChange;

  /// Emitted when the watcher is started.
  void watch();
}
