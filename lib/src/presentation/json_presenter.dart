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
    final Map<String, Object?> payload;
    switch (e) {
      case RunnerStarted():
        payload = {'event': 'started', 'ts': e.at.millisecondsSinceEpoch};
      case CompileStarted(:final trigger):
        payload = {
          'event': 'compileStarted',
          'ts': e.at.millisecondsSinceEpoch,
          'trigger': trigger,
        };
      case CompileSucceeded(:final elapsed):
        payload = {
          'event': 'compileSucceeded',
          'ts': e.at.millisecondsSinceEpoch,
          'elapsedMs': elapsed.inMilliseconds,
        };
      case CompileFailed(:final stderr):
        payload = {
          'event': 'compileFailed',
          'ts': e.at.millisecondsSinceEpoch,
          'stderr': stderr,
        };
      case ReloadSucceeded(:final kind):
        payload = {
          'event': 'reloadSucceeded',
          'ts': e.at.millisecondsSinceEpoch,
          'kind': kind.name,
        };
      case ReloadFailed(:final reason):
        payload = {
          'event': 'reloadFailed',
          'ts': e.at.millisecondsSinceEpoch,
          'reason': reason,
        };
      case RunnerStopped():
        payload = {
          'event': 'stopped',
          'ts': e.at.millisecondsSinceEpoch,
        };
    }
    _out.writeln(jsonEncode(payload));
  }
}
