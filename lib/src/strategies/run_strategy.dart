import 'dart:async';

import '../domain/events.dart';

enum ReloadOutcome { ok, fallbackUsed, failed }

abstract interface class RunStrategy {
  Stream<RunnerEvent> get events;
  Future<void> start();
  Future<ReloadOutcome> reload({String trigger});
  Future<void> send(Object? message);
  Future<void> dispose();
}
