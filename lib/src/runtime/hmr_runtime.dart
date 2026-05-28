import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../domain/events.dart';

/// Child-side runtime API. Lets the supervised application react to reload
/// lifecycle events the hmr supervisor emits.
///
/// Usage from your `bin/main.dart`:
///
/// ```dart
/// import 'package:hmr/runtime.dart';
///
/// void main() {
///   Hmr.instance.init();
///   Hmr.instance.onReload((_) => print('reloaded'));
///   Hmr.instance.onRestart((_) => print('restarted — re-initialising state'));
///   runApp();
/// }
/// ```
///
/// When not running under the supervisor (`HMR_PARENT_PID` unset), [init] is a
/// no-op and registered handlers simply never fire. This means production
/// builds need no conditional imports.
class Hmr {
  /// Process-wide instance. The child registers a single VM service extension
  /// — there is no useful reason to have multiple [Hmr]s in the same isolate.
  static final Hmr instance = Hmr._();

  Hmr._();

  /// Fresh, isolated instance for unit tests. Bypasses the static singleton so
  /// each test starts with an empty handler list.
  factory Hmr.forTesting() = Hmr._;

  final List<void Function(RunnerEvent)> _handlers = [];
  bool _extensionRegistered = false;

  /// True when the process was launched by the hmr supervisor (the supervisor
  /// sets `HMR_PARENT_PID` in the child's environment).
  bool get isActive => Platform.environment['HMR_PARENT_PID'] != null;

  /// Registers the `ext.hmr.dispatch` VM service extension so the parent can
  /// forward events. Safe to call multiple times. No-op when [isActive] is
  /// false, so production code can call it unconditionally.
  void init() {
    if (_extensionRegistered || !isActive) return;
    _extensionRegistered = true;
    developer.registerExtension('ext.hmr.dispatch', _handleDispatch);
  }

  /// Registers a handler for events of type [E]. Subscribe to [RunnerEvent] to
  /// receive every event.
  void on<E extends RunnerEvent>(void Function(E event) handler) {
    _handlers.add((event) {
      if (event is E) handler(event);
    });
  }

  /// Fires after every successful hot reload (state preserved).
  void onReload(void Function(ReloadSucceeded event) handler) {
    on<ReloadSucceeded>((e) {
      if (e.kind == ReloadKind.hotReload) handler(e);
    });
  }

  /// Fires after every successful hot restart (state lost — main() re-runs).
  /// Use this to re-warm caches, re-open connections, etc.
  void onRestart(void Function(ReloadSucceeded event) handler) {
    on<ReloadSucceeded>((e) {
      if (e.kind == ReloadKind.hotRestart) handler(e);
    });
  }

  void onFileCreated(void Function(FsCreated change) handler) =>
      _onFile<FsCreated>(handler);

  void onFileModified(void Function(FsModified change) handler) =>
      _onFile<FsModified>(handler);

  void onFileDeleted(void Function(FsDeleted change) handler) =>
      _onFile<FsDeleted>(handler);

  void onFileMoved(void Function(FsMoved change) handler) =>
      _onFile<FsMoved>(handler);

  void _onFile<E extends FsEvent>(void Function(E change) handler) {
    on<FileChanged>((event) {
      final change = event.change;
      if (change is E) handler(change);
    });
  }

  /// Routes an event to every registered handler, isolating errors so a
  /// misbehaving hook can never crash the supervised app.
  void dispatch(RunnerEvent event) {
    for (final handler in _handlers) {
      try {
        handler(event);
      } catch (e, st) {
        stderr.writeln('[hmr.runtime] handler threw: $e\n$st');
      }
    }
  }

  Future<developer.ServiceExtensionResponse> _handleDispatch(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final raw = parameters['event'];
      if (raw == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'missing "event" parameter',
        );
      }
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      dispatch(RunnerEvent.fromJson(json));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
    } catch (e, st) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        '$e\n$st',
      );
    }
  }
}
