import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/strategies/isolate_restart_strategy.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('start emits RunnerStarted, CompileStarted, CompileSucceeded, ReloadSucceeded', () async {
    final tmp = await Directory.systemTemp.createTemp('hmr-irs-');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    final strat = IsolateRestartStrategy(
      entrypoint: File(p.join('test', 'mocks', 'app.dart')),
      tempDirectory: tmp,
    );

    final events = <RunnerEvent>[];
    final sub = strat.events.listen(events.add);
    await strat.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();
    await strat.dispose();

    expect(events.whereType<RunnerStarted>(), hasLength(1));
    expect(events.whereType<CompileSucceeded>(), hasLength(1));
    expect(events.whereType<ReloadSucceeded>()
        .where((e) => e.kind == ReloadKind.hotRestart), hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('concurrent reload() calls serialize without corruption', () async {
    final tmp = await Directory.systemTemp.createTemp('hmr-irs-lock-');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    final strat = IsolateRestartStrategy(
      entrypoint: File(p.join('test', 'mocks', 'app.dart')),
      tempDirectory: tmp,
    );
    await strat.start();

    final results = await Future.wait([
      strat.reload(trigger: 'a'),
      strat.reload(trigger: 'b'),
      strat.reload(trigger: 'c'),
    ]);

    expect(results, hasLength(3));
    expect(File(p.join(tmp.path, 'app.dill')).existsSync(), isTrue);
    await strat.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
