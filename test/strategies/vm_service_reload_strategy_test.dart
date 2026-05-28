import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/strategies/run_strategy.dart';
import 'package:hmr/src/strategies/vm_service_reload_strategy.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal Process stub — only kill() and exitCode are called by the strategy.
class _FakeProcess implements Process {
  final _exitCompleter = Completer<int>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(0);
    return true;
  }

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  int get pid => 0;
}

/// Minimal VmService stub — only getVM(), reloadSources(), and dispose() are used.
class _FakeVmService extends VmService {
  final Queue<bool> _reloadResults;
  bool disposed = false;

  _FakeVmService(List<bool> results)
      : _reloadResults = Queue.of(results),
        super(const Stream.empty(), (_) {});

  @override
  Future<VM> getVM() async {
    return VM()
      ..isolates = [
        IsolateRef(id: 'isolates/1', isSystemIsolate: false),
      ];
  }

  @override
  Future<ReloadReport> reloadSources(
    String isolateId, {
    bool? force,
    bool? pause,
    String? rootLibUri,
    String? packagesUri,
  }) async {
    final success = _reloadResults.removeFirst();
    return ReloadReport()..success = success;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Process _fakeProcess() => _FakeProcess();

(Process, VmService, Stream<String>) _fakeLaunchResult(_FakeVmService svc) =>
    (_fakeProcess(), svc, Stream<String>.empty());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late File entrypoint;

  setUp(() => entrypoint = File('lib/main.dart'));

  test('reload returns ok and emits hotReload when reloadSources succeeds',
      () async {
    final fakeService = _FakeVmService([true]);

    final strategy = VmServiceReloadStrategy(
      entrypoint: entrypoint,
      launcher: (_, __) async => _fakeLaunchResult(fakeService),
    );

    final events = <RunnerEvent>[];
    strategy.events.listen(events.add);

    await strategy.start();
    final outcome = await strategy.reload(trigger: 'test.dart');
    await strategy.dispose();

    expect(outcome, ReloadOutcome.ok);
    expect(events, [
      isA<RunnerStarted>(),
      isA<CompileStarted>(),
      isA<CompileSucceeded>(),
      isA<ReloadSucceeded>()
          .having((e) => e.kind, 'kind', ReloadKind.hotReload),
      isA<RunnerStopped>(),
    ]);
  });

  test('falls back to hotRestart when reloadSources reports failure', () async {
    int launchCount = 0;

    final strategy = VmServiceReloadStrategy(
      entrypoint: entrypoint,
      launcher: (_, __) async {
        launchCount++;
        // First launch: reload fails (shape change).
        // Second launch (after restart): succeeds.
        final svc = _FakeVmService(launchCount == 1 ? [false] : [true]);
        return _fakeLaunchResult(svc);
      },
    );

    final events = <RunnerEvent>[];
    strategy.events.listen(events.add);

    await strategy.start();
    final outcome = await strategy.reload(trigger: 'test.dart');
    await strategy.dispose();

    expect(launchCount, 2, reason: 'should restart after shape-change failure');
    expect(outcome, ReloadOutcome.fallbackUsed);
    expect(
      events,
      containsAllInOrder([
        isA<RunnerStarted>(),
        isA<CompileStarted>(),
        isA<CompileSucceeded>(),
        isA<ReloadSucceeded>()
            .having((e) => e.kind, 'kind', ReloadKind.hotRestart),
        isA<RunnerStopped>(),
      ]),
    );
  });

  test('dispose emits RunnerStopped', () async {
    final strategy = VmServiceReloadStrategy(
      entrypoint: entrypoint,
      launcher: (_, __) async => _fakeLaunchResult(_FakeVmService([])),
    );

    final events = <RunnerEvent>[];
    strategy.events.listen(events.add);

    await strategy.start();
    await strategy.dispose();

    expect(events.last, isA<RunnerStopped>());
  });
}
