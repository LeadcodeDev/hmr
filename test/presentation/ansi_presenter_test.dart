import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/presentation/ansi_presenter.dart';
import 'package:hmr/src/version.dart';
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

Future<List<String>> _captureLines(List<RunnerEvent> events,
    {bool showBanner = false}) async {
  final sink = _CaptureSink();
  final presenter = AnsiPresenter(out: sink, showBanner: showBanner);
  final ctrl = StreamController<RunnerEvent>(sync: true);
  presenter.attach(ctrl.stream);
  for (final e in events) ctrl.add(e);
  await ctrl.close();
  // Banner rendering kicks off async work; await the cached version future
  // to ensure it has resolved, then yield to the event loop for the writes.
  await resolveHmrVersion();
  await Future<void>.delayed(Duration.zero);
  return sink.output
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
}

void main() {
  final ts = DateTime.fromMillisecondsSinceEpoch(1000);

  test('RunnerStarted writes non-empty output (banner off)', () async {
    final lines = await _captureLines([RunnerStarted(ts)]);
    expect(lines, isNotEmpty);
  });

  test('RunnerStarted with banner renders HMR, version and entrypoint',
      () async {
    final lines = await _captureLines([
      RunnerStarted(ts,
          elapsed: const Duration(milliseconds: 215),
          entrypoint: 'bin/main.dart'),
    ], showBanner: true);
    // Strip ANSI escape sequences for substring assertions.
    final plain = lines.join('\n').replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
    expect(plain, contains('HMR'));
    expect(plain, contains('ready in '));
    expect(plain, contains('215 ms'));
    expect(plain, contains('bin/main.dart'));
    expect(plain, contains('press '));
  });

  test('CompileFailed writes the stderr content', () async {
    final lines =
        await _captureLines([CompileFailed(ts, 'Undefined name foo')]);
    expect(lines.join(), contains('Undefined name foo'));
  });

  test('RunnerStopped produces no output', () async {
    final lines = await _captureLines([RunnerStopped(ts)]);
    expect(lines, isEmpty);
  });

  test('ProcessCrashed shows exit code, full stderr, and the restart hint',
      () async {
    final trace = 'Unhandled exception:\nStateError: boom\n'
        '#0      foo (file:///x.dart:1:1)\n'
        '#1      bar (file:///y.dart:2:2)';
    final lines = await _captureLines([ProcessCrashed(ts, 137, trace)]);
    final joined = lines.join('\n');
    expect(joined, contains('exited with code 137'));
    // Every stack frame survives.
    expect(joined, contains('StateError: boom'));
    expect(joined, contains('#0      foo'));
    expect(joined, contains('#1      bar'));
    expect(joined, contains('press R to restart'));
  });

  test('each reload cycle writes at least two output blocks', () async {
    final lines = await _captureLines([
      RunnerStarted(ts),
      CompileStarted(ts, 'lib/foo.dart'),
      CompileSucceeded(ts, const Duration(milliseconds: 50)),
      ReloadSucceeded(ts, ReloadKind.hotRestart),
    ]);
    expect(lines.length, greaterThanOrEqualTo(2));
  });
}
