import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/presentation/json_presenter.dart';
import 'package:test/test.dart';

List<Map<String, Object?>> _collect(List<RunnerEvent> events) {
  final lines = <String>[];
  final sink = _StringSink(lines);
  final presenter = JsonPresenter(out: sink);
  final ctrl = StreamController<RunnerEvent>(sync: true);
  presenter.attach(ctrl.stream);
  for (final e in events) ctrl.add(e);
  ctrl.close();
  return lines.map((l) => jsonDecode(l) as Map<String, Object?>).toList();
}

void main() {
  final ts = DateTime.fromMillisecondsSinceEpoch(1000);

  test('RunnerStarted emits started event', () {
    final out = _collect([RunnerStarted(ts)]);
    expect(out, hasLength(1));
    expect(out[0]['event'], 'started');
    expect(out[0]['ts'], 1000);
  });

  test('CompileStarted includes trigger', () {
    final out = _collect([CompileStarted(ts, 'lib/foo.dart')]);
    expect(out[0]['event'], 'compileStarted');
    expect(out[0]['trigger'], 'lib/foo.dart');
  });

  test('CompileSucceeded includes elapsedMs', () {
    final out = _collect([
      CompileSucceeded(ts, const Duration(milliseconds: 123)),
    ]);
    expect(out[0]['event'], 'compileSucceeded');
    expect(out[0]['elapsedMs'], 123);
  });

  test('CompileFailed includes stderr', () {
    final out = _collect([CompileFailed(ts, 'Unresolved reference')]);
    expect(out[0]['event'], 'compileFailed');
    expect(out[0]['stderr'], 'Unresolved reference');
  });

  test('ReloadSucceeded includes kind name', () {
    final out = _collect([ReloadSucceeded(ts, ReloadKind.hotReload)]);
    expect(out[0]['event'], 'reloadSucceeded');
    expect(out[0]['kind'], 'hotReload');
  });

  test('ReloadFailed includes reason', () {
    final out = _collect([ReloadFailed(ts, 'connection refused')]);
    expect(out[0]['event'], 'reloadFailed');
    expect(out[0]['reason'], 'connection refused');
  });

  test('ProcessCrashed preserves the full stack trace verbatim', () {
    final trace = '''
Unhandled exception:
StateError: boom
#0      foo (file:///x.dart:1:1)
#1      bar (file:///y.dart:2:2)
#2      _delayEntrypointInvocation.<anonymous closure>'''
        .trim();
    final out = _collect([ProcessCrashed(ts, 137, trace)]);
    expect(out[0]['event'], 'processCrashed');
    expect(out[0]['exitCode'], 137);
    // No truncation, no reformatting — the whole trace is one string.
    expect(out[0]['stderr'], trace);
  });

  test('RunnerStopped emits stopped event', () {
    final out = _collect([RunnerStopped(ts)]);
    expect(out[0]['event'], 'stopped');
  });

  test('emits one JSON line per event', () {
    final out = _collect([
      RunnerStarted(ts),
      CompileStarted(ts, 'f'),
      CompileSucceeded(ts, Duration.zero),
      ReloadSucceeded(ts, ReloadKind.hotRestart),
      RunnerStopped(ts),
    ]);
    expect(out, hasLength(5));
  });
}

// Minimal IOSink that captures writeln calls.
class _StringSink implements IOSink {
  final List<String> _lines;
  _StringSink(this._lines);

  @override
  void writeln([Object? obj = '']) => _lines.add(obj?.toString() ?? '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Encoding get encoding => utf8;
}
