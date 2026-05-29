import 'dart:async';

import '../domain/events.dart';

enum ReloadOutcome { ok, fallbackUsed, failed }

abstract interface class RunStrategy {
  Stream<RunnerEvent> get events;
  Future<void> start();
  Future<ReloadOutcome> reload({String trigger, FsEvent? fileEvent});

  /// Forces a full restart of the child, bypassing hot reload. Emits the same
  /// `CompileStarted → CompileSucceeded → ReloadSucceeded(hotRestart)` shape
  /// as a shape-change fallback.
  Future<ReloadOutcome> restart({String trigger, FsEvent? fileEvent});

  Future<void> send(Object? message);
  Future<void> dispose();
}
