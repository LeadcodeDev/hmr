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

  Future<void> init() async {
    try {
      final isolate = await _service.getIsolate(_isolateId);
      _available =
          isolate.extensionRPCs?.contains(extensionName) ?? false;
    } catch (_) {
      _available = false;
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
