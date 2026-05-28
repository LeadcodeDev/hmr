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

  void _render(RunnerEvent e) {
    final ts = e.at.millisecondsSinceEpoch;
    final Map<String, Object?> payload;
    switch (e) {
      case RunnerStarted():
        payload = {'event': 'started', 'ts': ts};
      case FileChanged(:final change):
        payload = {
          'event': 'fileChanged',
          'ts': ts,
          'change': change.toJson(),
        };
      case CompileStarted(:final trigger, :final fileEvent):
        payload = {
          'event': 'compileStarted',
          'ts': ts,
          'trigger': trigger,
          if (fileEvent != null) 'fileEvent': fileEvent.toJson(),
        };
      case CompileSucceeded(:final elapsed):
        payload = {
          'event': 'compileSucceeded',
          'ts': ts,
          'elapsedMs': elapsed.inMilliseconds,
        };
      case CompileFailed(:final stderr):
        payload = {
          'event': 'compileFailed',
          'ts': ts,
          'stderr': stderr,
        };
      case ReloadSucceeded(:final kind):
        payload = {
          'event': 'reloadSucceeded',
          'ts': ts,
          'kind': kind.name,
        };
      case ReloadFailed(:final reason):
        payload = {
          'event': 'reloadFailed',
          'ts': ts,
          'reason': reason,
        };
      case ProcessCrashed(:final exitCode, :final stderr):
        payload = {
          'event': 'processCrashed',
          'ts': ts,
          'exitCode': exitCode,
          'stderr': stderr,
        };
      case RunnerStopped():
        payload = {'event': 'stopped', 'ts': ts};
    }
    _out.writeln(jsonEncode(payload));
  }
}
