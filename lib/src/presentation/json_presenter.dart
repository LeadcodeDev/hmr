import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/events.dart';
import 'presenter.dart';

/// Writes one JSON object per line for each [RunnerEvent].
///
/// Consumers parse each line independently; they must not rely on
/// pretty-printing or cross-line structure.
class JsonPresenter implements Presenter {
  final IOSink _out;
  StreamSubscription<RunnerEvent>? _sub;

  JsonPresenter({IOSink? out}) : _out = out ?? stdout;

  @override
  void attach(Stream<RunnerEvent> events) {
    _sub = events.listen(_render);
  }

  @override
  Future<void> dispose() async => _sub?.cancel();

  void _render(RunnerEvent event) {
    final ts = event.at.millisecondsSinceEpoch;

    final Map<String, Object?> payload = switch (event) {
      RunnerStarted(
        :final elapsed,
        :final entrypoint,
        :final serviceUri,
        :final devToolsUri,
      ) =>
        {
          'event': 'started',
          'ts': ts,
          if (elapsed != null) 'elapsedMs': elapsed.inMilliseconds,
          if (entrypoint != null) 'entrypoint': entrypoint,
          if (serviceUri != null) 'serviceUri': serviceUri,
          if (devToolsUri != null) 'devToolsUri': devToolsUri,
        },
      FileChanged(:final change) => {
          'event': 'fileChanged',
          'ts': ts,
          'change': change.toJson(),
        },
      CompileStarted(:final trigger, :final fileEvent) => {
          'event': 'compileStarted',
          'ts': ts,
          'trigger': trigger,
          if (fileEvent != null) 'fileEvent': fileEvent.toJson(),
        },
      CompileSucceeded(:final elapsed) => {
          'event': 'compileSucceeded',
          'ts': ts,
          'elapsedMs': elapsed.inMilliseconds,
        },
      CompileFailed(:final stderr) => {
          'event': 'compileFailed',
          'ts': ts,
          'stderr': stderr,
        },
      ReloadSucceeded(:final kind) => {
          'event': 'reloadSucceeded',
          'ts': ts,
          'kind': switch (kind) {
            ReloadKind.hotReload => 'reload',
            ReloadKind.hotRestart => 'restart',
          },
        },
      ReloadFailed(:final reason) => {
          'event': 'reloadFailed',
          'ts': ts,
          'reason': reason,
        },
      ProcessCrashed(:final exitCode, :final stderr) => {
          'event': 'processCrashed',
          'ts': ts,
          'exitCode': exitCode,
          'stderr': stderr,
        },
      RunnerStopped() => {'event': 'stopped', 'ts': ts},
    };

    _out.writeln(jsonEncode(payload));
  }
}
