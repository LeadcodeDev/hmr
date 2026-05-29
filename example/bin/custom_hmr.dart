// Custom HMR runner built from the library's building blocks.
//
// Run from the example/ directory:
//   dart run bin/custom_hmr.dart
//
// This is the same composition the bundled `hmr` CLI performs, stripped
// down so the pieces are visible. Copy this file into your own project
// and adapt it when you need behaviour the default CLI doesn't expose
// (custom event sinks, a different watcher, extra hot keys, etc.).

import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final entrypoint = File(p.join(root, 'bin', 'main.dart'));

  // 1. Strategy — owns the child process and the VM service connection.
  final strategy = VmServiceProcessStrategy(
    entrypoint: entrypoint,
    args: args,
  );

  // 2. Watcher + filters — what counts as a reload trigger.
  final orchestrator = ReloadOrchestrator(
    strategy: strategy,
    watcher: FileWatcher(root),
    filters: [
      ignoreSegment(const ['.git', '.dart_tool', '.idea', '.vscode']),
      includeGlobs([Glob(p.join(root, '**.dart'))]),
    ],
    debounce: const Duration(milliseconds: 50),
  );

  // 3. Presenter — turn events into output. Here's a tiny custom one
  //    that prefixes every line with a timestamp. Swap in AnsiPresenter
  //    or JsonPresenter for the bundled formats.
  final presenter = _TimestampedPresenter()..attach(orchestrator.events);

  // 4. Hot keys — optional, but a one-liner.
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
      case HotKey.clear:
        break;
    }
  });
  hotKeys.start();

  await orchestrator.start();
}

class _TimestampedPresenter implements Presenter {
  StreamSubscription<RunnerEvent>? _sub;

  @override
  void attach(Stream<RunnerEvent> events) {
    _sub = events.listen((e) {
      final ts = DateTime.now().toIso8601String();
      stdout.writeln('[$ts] ${e.runtimeType}');
    });
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
