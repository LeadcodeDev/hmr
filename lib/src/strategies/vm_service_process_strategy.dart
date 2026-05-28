import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart';

import '../domain/events.dart';
import 'run_strategy.dart';
import 'vm_service_launcher.dart';

typedef VmServiceLauncherFn = Future<(Process, VmService, Stream<String>)>
    Function(File entrypoint, List<String> args);

class VmServiceProcessStrategy implements RunStrategy {
  final File entrypoint;
  final List<String> args;
  final VmServiceLauncherFn _launcher;

  Process? _process;
  VmService? _service;
  String? _mainIsolateId;
  Future<void>? _inFlight;

  final _events = StreamController<RunnerEvent>.broadcast();

  VmServiceProcessStrategy({
    required this.entrypoint,
    this.args = const [],
    VmServiceLauncherFn? launcher,
  }) : _launcher = launcher ?? launchWithVmService;

  @override
  Stream<RunnerEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    await _launch();
    _events.add(RunnerStarted(DateTime.now()));
  }

  Future<void> _launch() async {
    final (process, service, stderrLines) = await _launcher(entrypoint, args);
    _process = process;
    _service = service;
    final errors = <String>[];
    stderrLines.listen((line) {
      stderr.writeln(line);
      errors.add(line);
    });
    _mainIsolateId = await _resolveMainIsolateId(service);
    _watchForCrash(process, errors);
  }

  void _watchForCrash(Process process, List<String> errors) {
    process.exitCode.then((code) {
      if (code != 0 && identical(process, _process)) {
        _events.add(CompileFailed(DateTime.now(), errors.join('\n')));
      }
    });
  }

  Future<String> _resolveMainIsolateId(VmService service) async {
    final vm = await service.getVM();
    final isolates = vm.isolates ?? [];
    final main = isolates.firstWhere(
      (i) => !(i.isSystemIsolate ?? false),
      orElse: () => isolates.first,
    );
    return main.id!;
  }

  @override
  Future<ReloadOutcome> reload({String trigger = 'manual'}) async {
    final previous = _inFlight ?? Future.value();
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      await previous;
      return await _doReload(trigger);
    } finally {
      completer.complete();
      if (identical(_inFlight, completer.future)) _inFlight = null;
    }
  }

  Future<ReloadOutcome> _doReload(String trigger) async {
    _events.add(CompileStarted(DateTime.now(), trigger));
    final sw = Stopwatch()..start();

    final service = _service;
    final isolateId = _mainIsolateId;
    if (service == null || isolateId == null) {
      _events.add(CompileFailed(DateTime.now(), 'VM service not connected'));
      return ReloadOutcome.failed;
    }

    // Entry point changes require a full restart — main() won't re-execute
    // after a hot reload so any initialisation changes would be invisible.
    if (p.canonicalize(trigger) == p.canonicalize(entrypoint.path)) {
      return await _restartAfterCrash(sw);
    }

    try {
      final report = await service.reloadSources(isolateId, force: true);
      if (report.success ?? false) {
        _events.add(CompileSucceeded(DateTime.now(), sw.elapsed));
        _events.add(ReloadSucceeded(DateTime.now(), ReloadKind.hotReload));
        return ReloadOutcome.ok;
      }

      // Shape change — hot reload not possible, fall back to full restart
      final notices = report.json?['notices'];
      final reason = notices is List
          ? notices.map((n) => (n as Map?)?['message'] ?? n).join('; ')
          : 'no notices';
      stderr.writeln('[hmr] hot-reload rejected ($reason) — restarting');
      await _killProcess();
      await _launch();
      _events.add(CompileSucceeded(DateTime.now(), sw.elapsed));
      _events.add(ReloadSucceeded(DateTime.now(), ReloadKind.hotRestart));
      return ReloadOutcome.fallbackUsed;
    } on RPCError catch (e) {
      if (e.message == 'Service connection disposed') {
        return await _restartAfterCrash(sw);
      }
      _events.add(CompileFailed(DateTime.now(), e.message));
      return ReloadOutcome.failed;
    } catch (_) {
      return await _restartAfterCrash(sw);
    }
  }

  Future<ReloadOutcome> _restartAfterCrash(Stopwatch sw) async {
    try {
      await _killProcess();
      await _launch();
      _events.add(CompileSucceeded(DateTime.now(), sw.elapsed));
      _events.add(ReloadSucceeded(DateTime.now(), ReloadKind.hotRestart));
      return ReloadOutcome.fallbackUsed;
    } catch (restartErr) {
      _events.add(CompileFailed(DateTime.now(), restartErr.toString()));
      return ReloadOutcome.failed;
    }
  }

  Future<void> _killProcess() async {
    try {
      await _service?.dispose();
    } catch (_) {}
    _service = null;
    _mainIsolateId = null;
    final proc = _process;
    _process = null; // clear before kill so _watchForCrash ignores this exit
    proc?.kill(ProcessSignal.sigterm);
    try {
      await proc?.exitCode;
    } catch (_) {}
  }

  @override
  Future<void> send(Object? message) async {
    // Use dart:developer service extensions for app communication.
  }

  @override
  Future<void> dispose() async {
    await _killProcess();
    _events.add(RunnerStopped(DateTime.now()));
    await _events.close();
  }
}
