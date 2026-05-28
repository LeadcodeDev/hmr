import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/presentation/ansi_presenter.dart';
import 'package:test/test.dart';

class _CaptureSink implements IOSink {
  final _buf = StringBuffer();

  String get output => _buf.toString();

  @override
  void write(Object? obj) => _buf.write(obj ?? '');

  @override
  void writeln([Object? obj = '']) {
    _buf.write(obj ?? '');
    _buf.writeln();
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Encoding get encoding => utf8;
}

List<String> _captureLines(List<RunnerEvent> events) {
  final sink = _CaptureSink();
  final presenter = AnsiPresenter(out: sink);
  final ctrl = StreamController<RunnerEvent>(sync: true);
  presenter.attach(ctrl.stream);
  for (final e in events) ctrl.add(e);
  ctrl.close();
  return sink.output
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
}

void main() {
  final ts = DateTime.fromMillisecondsSinceEpoch(1000);

  test('RunnerStarted writes non-empty output', () {
    final lines = _captureLines([RunnerStarted(ts)]);
    expect(lines, isNotEmpty);
  });

  test('CompileFailed writes the stderr content', () {
    final lines = _captureLines([CompileFailed(ts, 'Undefined name foo')]);
    expect(lines.join(), contains('Undefined name foo'));
  });

  test('RunnerStopped produces no output', () {
    final sink = _CaptureSink();
    final presenter = AnsiPresenter(out: sink);
    final ctrl = StreamController<RunnerEvent>(sync: true);
    presenter.attach(ctrl.stream);
    ctrl.add(RunnerStopped(ts));
    ctrl.close();
    expect(sink.output, isEmpty);
  });

  test('ProcessCrashed shows exit code, full stderr, and the restart hint',
      () {
    final trace = 'Unhandled exception:\nStateError: boom\n'
        '#0      foo (file:///x.dart:1:1)\n'
        '#1      bar (file:///y.dart:2:2)';
    final lines = _captureLines([ProcessCrashed(ts, 137, trace)]);
    final joined = lines.join('\n');
    expect(joined, contains('exited with code 137'));
    // Every stack frame survives.
    expect(joined, contains('StateError: boom'));
    expect(joined, contains('#0      foo'));
    expect(joined, contains('#1      bar'));
    expect(joined, contains('press R to restart'));
  });

  test('each reload cycle writes at least two output blocks', () {
    final lines = _captureLines([
      RunnerStarted(ts),
      CompileStarted(ts, 'lib/foo.dart'),
      CompileSucceeded(ts, const Duration(milliseconds: 50)),
      ReloadSucceeded(ts, ReloadKind.hotRestart),
    ]);
    expect(lines.length, greaterThanOrEqualTo(2));
  });
}
