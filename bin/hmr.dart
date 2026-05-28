import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  final pubSpecFile = File('pubspec.yaml');

  if (!pubSpecFile.existsSync()) {
    stderr.writeln('[hmr] pubspec.yaml not found, please run inside a Dart project.');
    exit(1);
  }

  final pubSpec = await pubSpecFile.readAsYaml();

  Config? config;
  if (pubSpec['hmr'] != null) {
    try {
      config = Config.of(pubSpec['hmr']);
    } on ConfigError catch (e) {
      stderr.writeln('[hmr] config error: $e');
      exit(1);
    }
  }

  final entryParts = <String>[Directory.current.path];
  if (config?.entrypoint case final String e) {
    entryParts.add(e);
  } else {
    entryParts.addAll(['bin', '${pubSpec['name']}.dart']);
  }

  final tempDir = await Directory.systemTemp.createTemp('hmr');
  final strategy = IsolateRestartStrategy(
    entrypoint: File(path.joinAll(entryParts)),
    tempDirectory: tempDir,
    args: arguments,
  );

  final orchestrator = ReloadOrchestrator(
    strategy: strategy,
    watcher: FileWatcher(Directory.current.path),
    filters: [
      ignoreSegment(const ['~', '.git', '.dart_tool', '.idea', '.vscode']),
      if (config?.excludes case final List<Glob> ex) excludeGlobs(ex),
      includeGlobs(config?.includes ?? [Glob('**.dart')]),
    ],
    debounce: Duration(milliseconds: config?.debounce ?? 0),
  );

  final presenter = AnsiPresenter()..attach(orchestrator.events);

  Future<void> cleanup() async {
    await orchestrator.stop();
    await presenter.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanup());
  ProcessSignal.sigterm.watch().listen((_) => cleanup());

  await orchestrator.start();
}
