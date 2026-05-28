import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:hmr/src/contracts/hmr.dart';
import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as path;

final class Runner implements RunnerContract {
  @override
  final File entrypoint;

  @override
  final Directory tempDirectory;

  @override
  final String isolateName;

  final List<String> args;

  late File dillFile;
  Isolate? _isolate;

  ReceivePort? _receivePort;
  SendPort? _sendPort;
  Stream<dynamic>? _broadcast;

  Process? _compileProc;
  Future<void>? _inFlight;

  Runner(
      {required this.entrypoint,
      required this.tempDirectory,
      this.isolateName = 'hmr',
      this.args = const []});

  @override
  Future<void> run() async {
    dillFile = File(path.join(tempDirectory.path, 'app.dill'));
    await reload();
  }

  @override
  Future<void> reload() async {
    _compileProc?.kill(ProcessSignal.sigterm);

    final previous = _inFlight ?? Future.value();
    final completer = Completer<void>();
    _inFlight = completer.future;

    try {
      await previous;
      await _doReload();
    } finally {
      completer.complete();
      if (identical(_inFlight, completer.future)) _inFlight = null;
    }
  }

  Future<void> _doReload() async {
    final processResult = await _compile();
    if (processResult.exitCode != 0) {
      _renderCompileError(processResult.stderr.toString());
      return;
    }

    await _killIsolateGracefully();

    _receivePort = ReceivePort();
    _isolate = await _runIsolate(_receivePort!.sendPort);
    _broadcast = _receivePort!.asBroadcastStream();
    _sendPort = await _broadcast?.first;
  }

  void _renderCompileError(String error) {
    final cleaned =
        error.replaceAll('Bad state: Generating kernel failed!', '');

    final List<Sequence> sequences = [
      AsciiControl.lineFeed,
      SetStyles(Style.foreground(Color.red)),
      Print('Compilation failed:'),
      AsciiControl.lineFeed,
      AsciiControl.lineFeed,
    ];

    stderr.writeAnsiAll(sequences);
    stderr.writeln(cleaned);
    stderr
        .writeAnsiAll([const CursorPosition.moveUp(2), SetStyles(Style.reset)]);
  }

  Future<void> _killIsolateGracefully() async {
    final iso = _isolate;
    if (iso == null) return;
    _sendPort?.send(const {'__hmr__': 'shutdown'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    iso.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _sendPort = null;
  }

  Future<void> dispose() async {
    await _killIsolateGracefully();
    _receivePort?.close();
    try {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    } catch (e) {
      stderr.writeln('hmr: failed to clean temp directory: $e');
    }
  }

  Future<Isolate> _runIsolate(SendPort port) async {
    return Isolate.spawnUri(
      dillFile.uri,
      args,
      port,
      debugName: isolateName,
    );
  }

  Future<ProcessResult> _compile() async {
    final compileArgs = [
      'compile',
      'kernel',
      entrypoint.path,
      '-o',
      dillFile.path
    ];
    _compileProc = await Process.start(
      'dart',
      compileArgs,
      workingDirectory: Directory.current.path,
    );
    final stdoutF =
        _compileProc!.stdout.transform(systemEncoding.decoder).join();
    final stderrF =
        _compileProc!.stderr.transform(systemEncoding.decoder).join();
    final exitCode = await _compileProc!.exitCode;
    _compileProc = null;
    return ProcessResult(0, exitCode, await stdoutF, await stderrF);
  }

  @override
  Future<void> send(dynamic message) async {
    if (_sendPort == null) {
      final List<Sequence> sequences = [
        AsciiControl.lineFeed,
        SetStyles(Style.foreground(Color.red)),
        Print('Please send port from Isolate to parent'),
        AsciiControl.lineFeed,
        AsciiControl.lineFeed,
        AsciiControl.lineFeed,
      ];
      stderr.writeAnsiAll(sequences);
      return;
    }
    _sendPort!.send(message);
  }

  @override
  void listen(Function(dynamic message) handler) {
    _broadcast?.listen(handler);
  }
}
