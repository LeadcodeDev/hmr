import 'dart:convert';

import 'package:vm_service/vm_service.dart';

import '../domain/events.dart';

/// Forwards [RunnerEvent]s from the parent to the child process via a VM
/// service extension registered by `package:hmr/runtime.dart`.
///
/// The bridge is intentionally fire-and-forget: dispatch never throws, never
/// blocks reload progress, and silently no-ops when the child has not opted
/// into the runtime API. Call [init] after every (re)connect to refresh the
/// availability flag — the child re-registers the extension on each launch.
class RuntimeBridge {
  static const extensionName = 'ext.hmr.dispatch';

  final VmService _service;
  final String _isolateId;
  bool _available = false;

  RuntimeBridge({required VmService service, required String isolateId})
      : _service = service,
        _isolateId = isolateId;

  bool get isAvailable => _available;

  /// Polls the isolate until the runtime extension appears, bounded by
  /// [timeout]. The child registers `ext.hmr.dispatch` synchronously at the
  /// top of `main()`, but the parent can finish its VM-service handshake
  /// before that happens — so a single check would race with the child's
  /// startup. Apps that never opt into the runtime API simply burn the full
  /// timeout once at launch (and once per restart), which is acceptable.
  Future<void> init({
    Duration timeout = const Duration(milliseconds: 500),
    Duration pollInterval = const Duration(milliseconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        final isolate = await _service.getIsolate(_isolateId);
        if (isolate.extensionRPCs?.contains(extensionName) ?? false) {
          _available = true;
          return;
        }
      } catch (_) {
        // Transient — keep polling until the deadline.
      }
      if (!DateTime.now().isBefore(deadline)) {
        _available = false;
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> dispatch(RunnerEvent event) async {
    if (!_available) return;
    try {
      await _service.callServiceExtension(
        extensionName,
        isolateId: _isolateId,
        args: {'event': jsonEncode(event.toJson())},
      );
    } catch (_) {
      // Bridge failures must never destabilise the parent.
    }
  }
}
