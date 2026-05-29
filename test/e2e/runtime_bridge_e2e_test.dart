@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/orchestrator/runtime_bridge.dart';
import 'package:hmr/src/strategies/vm_service_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'event dispatched through the bridge round-trips into a real child Hmr',
    () async {
      final fixture = File(
        p.join(
          Directory.current.path,
          'test',
          'fixtures',
          'runtime_bridge_child.dart',
        ),
      );
      expect(fixture.existsSync(), isTrue, reason: 'fixture missing');

      final markerDir = await Directory.systemTemp.createTemp('hmr_bridge_e2e_');
      final marker = File(p.join(markerDir.path, 'events.ndjson'));

      final result = await launchWithVmService(fixture, [marker.path]);
      final process = result.process;
      final service = result.service;

      try {
        final vm = await service.getVM();
        final mainIsolate = (vm.isolates ?? []).firstWhere(
          (i) => !(i.isSystemIsolate ?? false),
          orElse: () => throw StateError('no main isolate'),
        );

        final bridge = RuntimeBridge(
          service: service,
          isolateId: mainIsolate.id!,
        );

        // The child registers ext.hmr.dispatch eagerly during main(), but the
        // extension RPC list takes a moment to reflect. Poll until available.
        for (var i = 0; i < 50 && !bridge.isAvailable; i++) {
          await bridge.init();
          if (!bridge.isAvailable) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        expect(
          bridge.isAvailable,
          isTrue,
          reason: 'child never registered ext.hmr.dispatch',
        );

        final at = DateTime.now();
        await bridge.dispatch(ReloadSucceeded(at, ReloadKind.hotReload));
        await bridge.dispatch(
          FileChanged(at, FsMoved('/old.dart', at, to: '/new.dart')),
        );
        await bridge.dispatch(RunnerStopped(at));

        // Handlers write synchronously; allow a brief retry for the third line
        // to land before we read.
        List<Map<String, Object?>> decoded = const [];
        for (var i = 0; i < 30; i++) {
          final lines = const LineSplitter()
              .convert(marker.readAsStringSync())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines.length >= 3) {
            decoded =
                lines.map((l) => jsonDecode(l) as Map<String, Object?>).toList();
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        expect(decoded, hasLength(3), reason: 'not all events reached child');

        expect(decoded[0]['type'], 'reloadSucceeded');
        expect(decoded[0]['kind'], 'reload');

        expect(decoded[1]['type'], 'fileChanged');
        final change = decoded[1]['change'] as Map<String, Object?>;
        expect(change['kind'], 'moved');
        expect(change['path'], '/old.dart');
        expect(change['to'], '/new.dart');

        expect(decoded[2]['type'], 'runnerStopped');
      } finally {
        try {
          await service.dispose();
        } catch (_) {}
        process.kill(ProcessSignal.sigterm);
        await process.exitCode;
        await markerDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
