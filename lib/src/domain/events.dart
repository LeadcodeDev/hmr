sealed class FsEvent {
  final String path;
  final DateTime at;
  const FsEvent(this.path, this.at);

  Map<String, Object?> toJson() => {
        'kind': _kind,
        'path': path,
        'at': at.toIso8601String(),
        if (this is FsMoved) 'to': (this as FsMoved).to,
      };

  String get _kind => switch (this) {
        FsCreated() => 'created',
        FsModified() => 'modified',
        FsDeleted() => 'deleted',
        FsMoved() => 'moved',
      };

  static FsEvent fromJson(Map<String, Object?> json) {
    final path = json['path']! as String;
    final at = DateTime.parse(json['at']! as String);
    return switch (json['kind'] as String) {
      'created' => FsCreated(path, at),
      'modified' => FsModified(path, at),
      'deleted' => FsDeleted(path, at),
      'moved' => FsMoved(path, at, to: json['to'] as String?),
      final k => throw FormatException('Unknown FsEvent kind: $k'),
    };
  }
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

  Map<String, Object?> toJson();

  static RunnerEvent fromJson(Map<String, Object?> json) {
    final type = json['type'] as String;
    final at = DateTime.parse(json['at']! as String);
    return switch (type) {
      'runnerStarted' => RunnerStarted(
          at,
          elapsed: json['elapsedUs'] == null
              ? null
              : Duration(microseconds: json['elapsedUs']! as int),
          entrypoint: json['entrypoint'] as String?,
          serviceUri: json['serviceUri'] as String?,
          devToolsUri: json['devToolsUri'] as String?,
        ),
      'fileChanged' => FileChanged(
          at,
          FsEvent.fromJson((json['change']! as Map).cast<String, Object?>()),
        ),
      'compileStarted' => CompileStarted(
          at,
          json['trigger']! as String,
          fileEvent: json['fileEvent'] == null
              ? null
              : FsEvent.fromJson(
                  (json['fileEvent']! as Map).cast<String, Object?>(),
                ),
        ),
      'compileSucceeded' => CompileSucceeded(
          at,
          Duration(microseconds: json['elapsedUs']! as int),
        ),
      'compileFailed' => CompileFailed(at, json['stderr']! as String),
      'reloadSucceeded' => ReloadSucceeded(
          at,
          switch (json['kind']! as String) {
            'reload' => ReloadKind.hotReload,
            'restart' => ReloadKind.hotRestart,
            final k => throw FormatException('Unknown ReloadKind: $k'),
          },
        ),
      'reloadFailed' => ReloadFailed(at, json['reason']! as String),
      'processCrashed' => ProcessCrashed(
          at,
          json['exitCode']! as int,
          json['stderr']! as String,
        ),
      'runnerStopped' => RunnerStopped(at),
      _ => throw FormatException('Unknown RunnerEvent type: $type'),
    };
  }
}

class RunnerStarted extends RunnerEvent {
  final Duration? elapsed;
  final String? entrypoint;
  final String? serviceUri;
  final String? devToolsUri;
  const RunnerStarted(
    super.at, {
    this.elapsed,
    this.entrypoint,
    this.serviceUri,
    this.devToolsUri,
  });

  @override
  Map<String, Object?> toJson() => {
        'type': 'runnerStarted',
        'at': at.toIso8601String(),
        if (elapsed != null) 'elapsedUs': elapsed!.inMicroseconds,
        if (entrypoint != null) 'entrypoint': entrypoint,
        if (serviceUri != null) 'serviceUri': serviceUri,
        if (devToolsUri != null) 'devToolsUri': devToolsUri,
      };
}

/// Raw file-system signal, emitted after filtering but **before** debounce.
/// Use this to react to every accepted file event, even ones that get
/// coalesced into a single CompileStarted by the debounce window.
class FileChanged extends RunnerEvent {
  final FsEvent change;
  const FileChanged(super.at, this.change);

  @override
  Map<String, Object?> toJson() => {
        'type': 'fileChanged',
        'at': at.toIso8601String(),
        'change': change.toJson(),
      };
}

class CompileStarted extends RunnerEvent {
  final String trigger;
  final FsEvent? fileEvent;
  const CompileStarted(super.at, this.trigger, {this.fileEvent});

  @override
  Map<String, Object?> toJson() => {
        'type': 'compileStarted',
        'at': at.toIso8601String(),
        'trigger': trigger,
        if (fileEvent != null) 'fileEvent': fileEvent!.toJson(),
      };
}

class CompileSucceeded extends RunnerEvent {
  final Duration elapsed;
  const CompileSucceeded(super.at, this.elapsed);

  @override
  Map<String, Object?> toJson() => {
        'type': 'compileSucceeded',
        'at': at.toIso8601String(),
        'elapsedUs': elapsed.inMicroseconds,
      };
}

class CompileFailed extends RunnerEvent {
  final String stderr;
  const CompileFailed(super.at, this.stderr);

  @override
  Map<String, Object?> toJson() => {
        'type': 'compileFailed',
        'at': at.toIso8601String(),
        'stderr': stderr,
      };
}

class ReloadSucceeded extends RunnerEvent {
  final ReloadKind kind;
  const ReloadSucceeded(super.at, this.kind);

  @override
  Map<String, Object?> toJson() => {
        'type': 'reloadSucceeded',
        'at': at.toIso8601String(),
        'kind': switch (kind) {
          ReloadKind.hotReload => 'reload',
          ReloadKind.hotRestart => 'restart',
        },
      };
}

class ReloadFailed extends RunnerEvent {
  final String reason;
  const ReloadFailed(super.at, this.reason);

  @override
  Map<String, Object?> toJson() => {
        'type': 'reloadFailed',
        'at': at.toIso8601String(),
        'reason': reason,
      };
}

/// Emitted when the child process exits with a non-zero code unexpectedly
/// (uncaught exception in main, explicit exit(N), etc).
/// `stderr` carries the full buffered stderr verbatim — never truncated.
class ProcessCrashed extends RunnerEvent {
  final int exitCode;
  final String stderr;
  const ProcessCrashed(super.at, this.exitCode, this.stderr);

  @override
  Map<String, Object?> toJson() => {
        'type': 'processCrashed',
        'at': at.toIso8601String(),
        'exitCode': exitCode,
        'stderr': stderr,
      };
}

class RunnerStopped extends RunnerEvent {
  const RunnerStopped(super.at);

  @override
  Map<String, Object?> toJson() => {
        'type': 'runnerStopped',
        'at': at.toIso8601String(),
      };
}
