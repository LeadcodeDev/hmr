import 'dart:async';

import '../domain/events.dart';

abstract interface class Presenter {
  void attach(Stream<RunnerEvent> events);
  Future<void> dispose();
}
