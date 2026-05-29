import 'dart:async';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/orchestrator/reload_orchestrator.dart';
import 'package:hmr/src/pipeline/file_watcher.dart';
import 'package:hmr/src/strategies/run_strategy.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeStrategy implements RunStrategy {
  final _events = StreamController<RunnerEvent>.broadcast();
  final reloads = <String>[];
  final restarts = <String>[];

  @override
  Stream<RunnerEvent> get events => _events.stream;

  @override
  Future<void> start() async => _events.add(RunnerStarted(DateTime.now()));

  @override
  Future<ReloadOutcome> reload({
    String trigger = 'manual',
    FsEvent? fileEvent,
  }) async {
    reloads.add(trigger);
    return ReloadOutcome.ok;
  }

  @override
  Future<ReloadOutcome> restart({
    String trigger = 'manual',
    FsEvent? fileEvent,
  }) async {
    restarts.add(trigger);
    return ReloadOutcome.fallbackUsed;
  }

  @override
  Future<void> send(Object? m) async {}

  @override
  Future<void> dispose() async => _events.close();
}

void main() {
  test('writing a file triggers reload on the strategy', () async {
    final dir = await Directory.systemTemp.createTemp('hmr-orch-');
    addTearDown(() => dir.delete(recursive: true));

    final file = File(p.join(dir.path, 'a.dart'));
    await file.writeAsString('void main() {}');

    final strat = _FakeStrategy();
    final orch = ReloadOrchestrator(
      strategy: strat,
      watcher: FileWatcher(dir.path),
      debounce: const Duration(milliseconds: 50),
    );
    await orch.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await file.writeAsString('void main() { print("x"); }');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    await orch.stop();
    expect(strat.reloads, isNotEmpty);
    expect(strat.reloads.first, contains('a.dart'));
  });

  test('reload() and restart() proxy through to the strategy', () async {
    final strat = _FakeStrategy();
    final dir = await Directory.systemTemp.createTemp('hmr-orch-');
    addTearDown(() => dir.delete(recursive: true));

    final orch = ReloadOrchestrator(
      strategy: strat,
      watcher: FileWatcher(dir.path),
    );

    await orch.reload(trigger: 'hotkey:r');
    await orch.restart(trigger: 'hotkey:R');

    expect(strat.reloads, ['hotkey:r']);
    expect(strat.restarts, ['hotkey:R']);
  });
}
