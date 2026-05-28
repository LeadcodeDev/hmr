import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as path;

final _argParser = ArgParser()
  ..addOption(
    'strategy',
    abbr: 's',
    allowed: ['restart', 'vm'],
    defaultsTo: 'restart',
    help: 'Reload strategy: "restart" (isolate restart) or "vm" (hot reload via VM service).',
  )
  ..addOption(
    'format',
    abbr: 'f',
    allowed: ['ansi', 'json'],
    defaultsTo: 'ansi',
    help: 'Output format: "ansi" (human-readable) or "json" (one JSON object per line).',
  )
  ..addFlag(
    'rescan-extension',
    defaultsTo: false,
    help: 'Register ext.hmr.rescan service extension so IDEs can trigger reloads.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help message.');

Future<void> main(List<String> arguments) async {
  final ArgResults args;
  try {
    args = _argParser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('[hmr] ${e.message}');
    stderr.writeln(_argParser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    stdout.writeln('Usage: hmr [options] [-- app-args...]');
    stdout.writeln(_argParser.usage);
    exit(0);
  }

  final appArgs = args.rest;

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

  final entrypoint = File(path.joinAll(entryParts));

  final RunStrategy strategy;
  switch (args['strategy'] as String) {
    case 'vm':
      strategy = VmServiceProcessStrategy(
        entrypoint: entrypoint,
        args: appArgs,
      );
    case _:
      final tempDir = await Directory.systemTemp.createTemp('hmr');
      strategy = IsolateRestartStrategy(
        entrypoint: entrypoint,
        tempDirectory: tempDir,
        args: appArgs,
      );
  }

  // Glob.matches() canonicalises the input path to absolute before matching.
  // Relative patterns like **/*.dart compile to regexes that cannot match an
  // absolute path (they expect a non-'/' first character). Making the patterns
  // absolute here ensures the compiled regex anchors at the project root and
  // matches the canonicalised paths correctly.
  final root = Directory.current.path;
  List<Glob> absoluteGlobs(List<Glob>? globs, String fallback) =>
      (globs ?? [Glob(fallback)])
          .map((g) => Glob(path.join(root, g.pattern)))
          .toList();

  final orchestrator = ReloadOrchestrator(
    strategy: strategy,
    watcher: FileWatcher(root),
    filters: [
      ignoreSegment(const ['~', '.git', '.dart_tool', '.idea', '.vscode']),
      if (config?.excludes case final List<Glob> ex)
        excludeGlobs(absoluteGlobs(ex, '**')),
      includeGlobs(absoluteGlobs(config?.includes, '**.dart')),
    ],
    debounce: Duration(milliseconds: config?.debounce ?? 0),
  );

  final Presenter presenter;
  if (args['format'] == 'json') {
    presenter = JsonPresenter()..attach(orchestrator.events);
  } else {
    presenter = AnsiPresenter()..attach(orchestrator.events);
  }

  Future<void> cleanup() async {
    await orchestrator.stop();
    await presenter.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanup());
  ProcessSignal.sigterm.watch().listen((_) => cleanup());

  await orchestrator.start();
}
