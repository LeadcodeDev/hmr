sealed class FsEvent {
  final String path;
  final DateTime at;
  const FsEvent(this.path, this.at);
}

class FsCreated extends FsEvent {
  const FsCreated(super.path, super.at);
}

class FsModified extends FsEvent {
  const FsModified(super.path, super.at);
}

class FsDeleted extends FsEvent {
  const FsDeleted(super.path, super.at);
}

class FsMoved extends FsEvent {
  final String? to;
  const FsMoved(super.path, super.at, {this.to});
}

enum ReloadKind { hotReload, hotRestart }

sealed class RunnerEvent {
  final DateTime at;
  const RunnerEvent(this.at);
}

class RunnerStarted extends RunnerEvent {
  const RunnerStarted(super.at);
}

class CompileStarted extends RunnerEvent {
  final String trigger;
  const CompileStarted(super.at, this.trigger);
}

class CompileSucceeded extends RunnerEvent {
  final Duration elapsed;
  const CompileSucceeded(super.at, this.elapsed);
}

class CompileFailed extends RunnerEvent {
  final String stderr;
  const CompileFailed(super.at, this.stderr);
}

class ReloadSucceeded extends RunnerEvent {
  final ReloadKind kind;
  const ReloadSucceeded(super.at, this.kind);
}

class ReloadFailed extends RunnerEvent {
  final String reason;
  const ReloadFailed(super.at, this.reason);
}

class RunnerStopped extends RunnerEvent {
  const RunnerStopped(super.at);
}
