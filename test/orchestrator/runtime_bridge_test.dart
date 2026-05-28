import 'dart:convert';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/orchestrator/runtime_bridge.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

class _FakeVmService extends VmService {
  final List<String> isolateExtensions;
  final bool getIsolateThrows;
  final bool callThrows;
  final List<({String method, String? isolateId, Map<String, dynamic>? args})>
      calls = [];

  _FakeVmService({
    this.isolateExtensions = const [],
    this.getIsolateThrows = false,
    this.callThrows = false,
  }) : super(const Stream.empty(), (_) {});

  @override
  Future<Isolate> getIsolate(String isolateId) async {
    if (getIsolateThrows) throw StateError('boom');
    return Isolate(extensionRPCs: List.of(isolateExtensions));
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    calls.add((method: method, isolateId: isolateId, args: args));
    if (callThrows) throw RPCError(method, 0, 'extension threw');
    return Response.parse({'type': 'Success'})!;
  }
}

void main() {
  group('RuntimeBridge', () {
    test('init sets isAvailable=true when ext.hmr.dispatch is registered',
        () async {
      final svc = _FakeVmService(isolateExtensions: ['ext.hmr.dispatch']);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');

      await bridge.init();

      expect(bridge.isAvailable, isTrue);
    });

    test('init sets isAvailable=false when extension is absent', () async {
      final svc = _FakeVmService(isolateExtensions: ['ext.dart.timeDilation']);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');

      await bridge.init();

      expect(bridge.isAvailable, isFalse);
    });

    test('init swallows getIsolate errors and stays unavailable', () async {
      final svc = _FakeVmService(getIsolateThrows: true);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');

      await bridge.init();

      expect(bridge.isAvailable, isFalse);
    });

    test('dispatch no-ops when bridge is unavailable', () async {
      final svc = _FakeVmService(isolateExtensions: const []);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');
      await bridge.init();

      await bridge.dispatch(RunnerStarted(DateTime.now()));

      expect(svc.calls, isEmpty);
    });

    test('dispatch sends a JSON-encoded event payload to the extension',
        () async {
      final svc = _FakeVmService(isolateExtensions: ['ext.hmr.dispatch']);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');
      await bridge.init();

      final event = ReloadSucceeded(DateTime.now(), ReloadKind.hotReload);
      await bridge.dispatch(event);

      expect(svc.calls, hasLength(1));
      final call = svc.calls.single;
      expect(call.method, 'ext.hmr.dispatch');
      expect(call.isolateId, 'isolates/1');

      final raw = call.args!['event'] as String;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['type'], 'reloadSucceeded');
      expect(decoded['kind'], 'hotReload');
    });

    test('dispatch swallows RPC errors so the parent stays alive', () async {
      final svc = _FakeVmService(
        isolateExtensions: ['ext.hmr.dispatch'],
        callThrows: true,
      );
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');
      await bridge.init();

      await expectLater(
        bridge.dispatch(RunnerStarted(DateTime.now())),
        completes,
      );
    });

    test('FileChanged events round-trip through the bridge payload', () async {
      final svc = _FakeVmService(isolateExtensions: ['ext.hmr.dispatch']);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');
      await bridge.init();

      final at = DateTime.now();
      await bridge.dispatch(
        FileChanged(at, FsMoved('/old.dart', at, to: '/new.dart')),
      );

      final raw = svc.calls.single.args!['event'] as String;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['type'], 'fileChanged');
      expect(decoded['change']['kind'], 'moved');
      expect(decoded['change']['path'], '/old.dart');
      expect(decoded['change']['to'], '/new.dart');
    });

    test('init is idempotent and refreshes availability', () async {
      final svc = _FakeVmService(isolateExtensions: <String>[]);
      final bridge = RuntimeBridge(service: svc, isolateId: 'isolates/1');

      await bridge.init();
      expect(bridge.isAvailable, isFalse);

      svc.isolateExtensions.add('ext.hmr.dispatch');
      await bridge.init();
      expect(bridge.isAvailable, isTrue);
    });
  });
}
