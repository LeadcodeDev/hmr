import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../domain/events.dart';
import 'run_strategy.dart';

class IsolateRestartStrategy implements RunStrategy {
  final File entrypoint;
  final Directory tempDirectory;
  final String isolateName;
  final List<String> args;

  late File _dillFile;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _appPort;
  Stream<dynamic>? _broadcast;
  Process? _compileProc;
  Future<void>? _inFlight;

  final _events = StreamController<RunnerEvent>.broadcast();

  IsolateRestartStrategy({
    required this.entrypoint,
    required this.tempDirectory,
    this.isolateName = 'hmr',
    this.args = const [],
  });

  @override
  Stream<RunnerEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    _dillFile = File(p.join(tempDirectory.path, 'app.dill'));
    _events.add(RunnerStarted(DateTime.now()));
    await reload(trigger: 'startup');
  }

  @override
  Future<ReloadOutcome> reload({String trigger = 'manual'}) async {
    _compileProc?.kill(ProcessSignal.sigterm);
    final previous = _inFlight ?? Future.value();
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      await previous;
      return await _doReload(trigger);
    } finally {
      completer.complete();
      if (identical(_inFlight, completer.future)) _inFlight = null;
    }
  }

  Future<ReloadOutcome> _doReload(String trigger) async {
    _events.add(CompileStarted(DateTime.now(), trigger));
    final sw = Stopwatch()..start();
    final result = await _compile();
    if (result.exitCode != 0) {
      _events.add(CompileFailed(DateTime.now(),
          result.stderr.toString().replaceAll('Bad state: Generating kernel failed!', '')));
      return ReloadOutcome.failed;
    }
    _events.add(CompileSucceeded(DateTime.now(), sw.elapsed));
    await _killIsolate();
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawnUri(
      _dillFile.uri,
      args,
      _receivePort!.sendPort,
      debugName: isolateName,
    );
    _broadcast = _receivePort!.asBroadcastStream();
    _appPort = await _broadcast?.first as SendPort?;
    _events.add(ReloadSucceeded(DateTime.now(), ReloadKind.hotRestart));
    return ReloadOutcome.ok;
  }

  Future<void> _killIsolate() async {
    final iso = _isolate;
    if (iso == null) return;
    _appPort?.send(const {'__hmr__': 'shutdown'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    iso.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _appPort = null;
  }

  Future<ProcessResult> _compile() async {
    final compileArgs = ['compile', 'kernel', entrypoint.path, '-o', _dillFile.path];
    _compileProc = await Process.start(
      'dart',
      compileArgs,
      workingDirectory: Directory.current.path,
    );
    final stdoutF = _compileProc!.stdout.transform(systemEncoding.decoder).join();
    final stderrF = _compileProc!.stderr.transform(systemEncoding.decoder).join();
    final exitCode = await _compileProc!.exitCode;
    _compileProc = null;
    return ProcessResult(0, exitCode, await stdoutF, await stderrF);
  }

  @override
  Future<ReloadOutcome> restart({String trigger = 'manual'}) =>
      reload(trigger: trigger);

  @override
  Future<void> send(Object? message) async {
    _appPort?.send(message);
  }

  @override
  Future<void> dispose() async {
    await _killIsolate();
    _receivePort?.close();
    _events.add(RunnerStopped(DateTime.now()));
    await _events.close();
    try {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    } catch (_) {}
  }
}
