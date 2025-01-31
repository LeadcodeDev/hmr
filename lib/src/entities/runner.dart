import 'dart:io';
import 'dart:isolate';

import 'package:hmr/src/contracts/hmr.dart';
import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as path;

final class Runner implements RunnerContract {
  final File entrypoint;
  final Directory tempDirectory;

  late Directory tempPath;
  late File dillFile;
  Isolate? _isolate;
  bool needClearScreen = false;

  Runner({required this.entrypoint, required this.tempDirectory});

  Future<void> run() async {
    tempPath = await tempDirectory.createTemp('hmr');
    dillFile = File(path.join(tempPath.path, 'app.dill'));

    await reload();
  }

  Future<void> reload() async {
    final processResult = await _compile();
    if (processResult.exitCode != 0) {
      final error = processResult.stderr.toString()
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
      stderr.writeAnsiAll([
        const CursorPosition.moveUp(2),
        SetStyles(Style.reset)
      ]);

      return;
    }

    _isolate?.kill(priority: Isolate.immediate);

    final receivePort = ReceivePort();
    _isolate = await _runIsolate(receivePort.sendPort);
  }

  Future<Isolate> _runIsolate(SendPort port) async {
    return Isolate.spawnUri(
      dillFile.uri,
      [],
      port,
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
}
