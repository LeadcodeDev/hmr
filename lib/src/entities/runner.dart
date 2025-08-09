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
  bool needClearScreen = false;

  ReceivePort? _receivePort;
  SendPort? _sendPort;
  Stream<dynamic>? _broadcast;

  Runner(
      {required this.entrypoint,
      required this.tempDirectory,
      this.isolateName = 'hmr',
      this.args = const []});

  @override
  Future<void> run() async {
    dillFile = File(path.join(tempDirectory.path, 'app.dill'));

    // Listen for app shutdown events
    ProcessSignal.sigint.watch().listen((signal) {
      dispose().then((_) => exit(0));
    });

    ProcessSignal.sigterm.watch().listen((signal) {
      dispose().then((_) => exit(0));
    });

    await reload();
  }

  @override
  Future<void> reload() async {
    final processResult = await _compile();
    if (processResult.exitCode != 0) {
      final error = processResult.stderr
          .toString()
          .replaceAll('Bad state: Generating kernel failed!', '');

      final List<Sequence> sequences = [
        AsciiControl.lineFeed,
        SetStyles(Style.foreground(Color.red)),
        Print('Compilation failed:'),
        AsciiControl.lineFeed,
        AsciiControl.lineFeed,
      ];

      stderr.writeAnsiAll(sequences);
      stderr.writeln(error);
      stderr.writeAnsiAll(
          [const CursorPosition.moveUp(2), SetStyles(Style.reset)]);

      return;
    }

    _isolate?.kill(priority: Isolate.immediate);

    _receivePort = ReceivePort();
    _isolate = await _runIsolate(_receivePort!.sendPort);
    _broadcast = _receivePort!.asBroadcastStream();
    _sendPort = await _broadcast?.first;
  }

  Future<void> dispose() async {
    try {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    } catch (e) {
      stderr.writeln('❌ Error cleaning temp directory: $e');
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

  Future<ProcessResult> _compile() {
    final args = ['compile', 'kernel', entrypoint.path, '-o', dillFile.path];
    return Process.run(
      'dart',
      args,
      workingDirectory: Directory.current.path,
    );
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
