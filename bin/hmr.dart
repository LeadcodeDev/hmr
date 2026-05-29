import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as path;

final _argParser = ArgParser()
  ..addOption(
    'format',
    abbr: 'f',
    allowed: ['ansi', 'json'],
    defaultsTo: 'ansi',
    help:
        'Output format: "ansi" (human-readable) or "json" (one JSON object per line).',
  )
  ..addFlag('help',
      abbr: 'h', negatable: false, help: 'Show this help message.');

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
    stderr.writeln(
        '[hmr] pubspec.yaml not found, please run inside a Dart project.');
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
  if (!entrypoint.existsSync()) {
    final red = stderr.hasTerminal ? '\x1B[31m' : '';
    final reset = stderr.hasTerminal ? '\x1B[0m' : '';
    stderr.writeln('$red[hmr] entrypoint not found: ${entrypoint.path}$reset');

    if (config?.entrypoint != null) {
      stderr.writeln(
        '$red[hmr] check the `hmr.entrypoint` value in pubspec.yaml.$reset',
      );
    } else {
      stderr.writeln(
        '$red[hmr] set `hmr.entrypoint` in pubspec.yaml or create bin/${pubSpec['name']}.dart.$reset',
      );
    }
    exit(1);
  }

  final strategy = VmServiceProcessStrategy(
    entrypoint: entrypoint,
    args: appArgs,
  );

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

  // `.dart_tool` is always excluded — the user cannot opt back in. Everything
  // else is overridable: when `hmr.excludes` is set in pubspec.yaml the user
  // takes full responsibility for what gets filtered, otherwise we apply a
  // sensible default list (tests, build/doc dirs, IDE config, editor temp
  // artefacts).
  final excludes = config?.excludes ?? defaultExcludes;
  final orchestrator = ReloadOrchestrator(
    strategy: strategy,
    watcher: FileWatcher(root),
    filters: [
      ignoreSegment(const ['.dart_tool']),
      excludeGlobs(absoluteGlobs(excludes, '**')),
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

  final hotKeys = HotKeyController();

  var shuttingDown = false;
  Future<void> cleanup() async {
    if (shuttingDown) return;
    shuttingDown = true;

    await hotKeys.stop();
    await orchestrator.stop();
    await presenter.dispose();

    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanup());
  ProcessSignal.sigterm.watch().listen((_) => cleanup());

  hotKeys.keys.listen((key) {
    switch (key) {
      case HotKey.reload:
        orchestrator.reload(trigger: 'hotkey:r');
      case HotKey.restart:
        orchestrator.restart(trigger: 'hotkey:R');
      case HotKey.quit:
      case HotKey.ctrlC:
        cleanup();
      case HotKey.help:
        stderr.writeln(
          '[hmr] r: reload | R: restart | c: clear | q: quit | h: help',
        );
      case HotKey.clear:
        stdout.write('\x1B[2J\x1B[H');
    }
  });

  hotKeys.start();

  await orchestrator.start();
}
