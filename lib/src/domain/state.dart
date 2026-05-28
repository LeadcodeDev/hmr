import 'dart:async';
import 'dart:isolate';

sealed class RunnerState {
  const RunnerState();
}

class Idle extends RunnerState {
  const Idle();
}

class Compiling extends RunnerState {
  final Completer<void> cancel;
  Compiling(this.cancel);
}

class Running extends RunnerState {
  final Isolate isolate;
  final SendPort? appPort;
  const Running(this.isolate, this.appPort);
}

class Failed extends RunnerState {
  final String stderr;
  const Failed(this.stderr);
}
