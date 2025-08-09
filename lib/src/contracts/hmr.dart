import 'dart:async';
import 'dart:io';

abstract interface class RunnerContract {
  /// The entrypoint file to run.
  File get entrypoint;

  /// The [Isolate] name.
  String get isolateName;

  /// The temporary directory to store the compiled files.
  Directory get tempDirectory;

  /// Run the entrypoint file.
  Future<void> run();

  /// Reload the entrypoint file.
  Future<void> reload();

  /// Send a message to the isolate.
  Future<void> send(dynamic message);

  /// Listen for messages from the isolate.
  void listen(Function(dynamic message) handler);
}

abstract interface class WatcherContract {
  /// The list of executed middlewares before trigger the watcher emitter.
  List<MiddlewareWatcher> get middlewares;

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

/// The next function to execute the next middleware.
typedef NextFn = Function();

abstract interface class MiddlewareWatcher {
  /// Handle the [FileSystemEvent] and execute the next middleware.
  void handle(FileSystemEvent event, NextFn next);
}
