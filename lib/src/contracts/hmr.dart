import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';

abstract interface class RunnerContract {
  File get entrypoint;
  Directory get tempDirectory;

  Future<void> run();

  Future<void> reload();
}

abstract interface class WatcherContract {
  List<Glob> get includes;

  FutureOr Function(File)? get onFileModify;
  FutureOr Function(File)? get onFileCreate;
  FutureOr Function(File)? get onFileDelete;
  FutureOr Function(File)? get onFileMove;
  FutureOr Function(int type, File)? get onFileChange;

  void watch();
}
