import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/vm_service.dart';

/// Output of [launchWithVmService]. Carries the live child process, an open
/// VM service connection, the post-URI stderr stream, and the URLs the VM
/// printed at startup (used by presenters to surface debug entrypoints).
class LaunchResult {
  final Process process;
  final VmService service;
  final Stream<String> stderrLines;
  final String serviceUri;
  final String? devToolsUri;

  LaunchResult({
    required this.process,
    required this.service,
    required this.stderrLines,
    required this.serviceUri,
    required this.devToolsUri,
  });
}

/// Spawns a Dart child process with the VM service enabled and connects to it.
Future<LaunchResult> launchWithVmService(
  File entrypoint,
  List<String> args,
) async {
  final process = await Process.start(
    'dart',
    [
      '--enable-vm-service=0',
      entrypoint.path,
      ...args,
    ],
    environment: {
      'HMR_PARENT_PID': pid.toString(),
      'FORCE_COLOR': '1',
    },
  );

  final stderrController = StreamController<String>.broadcast();
  final serviceUriCompleter = Completer<String>();
  final devToolsUriCompleter = Completer<String?>();
  final servicePattern = RegExp(r'listening on (https?://\S+)');
  final devToolsPattern =
      RegExp(r'DevTools debugger and profiler is available at:\s*(\S+)');

  void scan(String line) {
    if (!serviceUriCompleter.isCompleted) {
      final match = servicePattern.firstMatch(line);
      if (match != null) serviceUriCompleter.complete(match.group(1)!);
    }
    if (!devToolsUriCompleter.isCompleted) {
      final match = devToolsPattern.firstMatch(line);
      if (match != null) devToolsUriCompleter.complete(match.group(1)!);
    }
  }

  // Dart 3.8+ prints the VM service URI to stdout; earlier versions used
  // stderr. Scan both so we handle either runtime. VM service info lines
  // are suppressed from terminal output since HMR owns the process lifecycle.
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        scan(line);
        if (!_isVmServiceLine(line)) stdout.writeln(line);
      });

  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          scan(line);
          if (!_isVmServiceLine(line)) stderrController.add(line);
        },
        onError: (Object e, StackTrace st) {
          stderrController.addError(e, st);
          if (!serviceUriCompleter.isCompleted) {
            serviceUriCompleter.completeError(e, st);
          }
          if (!devToolsUriCompleter.isCompleted) {
            devToolsUriCompleter.complete(null);
          }
        },
        onDone: () {
          stderrController.close();
          if (!serviceUriCompleter.isCompleted) {
            serviceUriCompleter.completeError(
              StateError('VM service URI not found in child process output'),
            );
          }
          if (!devToolsUriCompleter.isCompleted) {
            devToolsUriCompleter.complete(null);
          }
        },
      );

  final serviceUri = await serviceUriCompleter.future;
  final service = await vmServiceConnectUri(wsUriFromHttpUri(serviceUri));

  // DevTools is printed right after the service line on the same channel,
  // so it's already in flight. Wait briefly for it; if it never arrives
  // (e.g. --disable-dart-dev), fall back to null.
  final devToolsUri = await devToolsUriCompleter.future
      .timeout(const Duration(seconds: 1), onTimeout: () => null);

  return LaunchResult(
    process: process,
    service: service,
    stderrLines: stderrController.stream,
    serviceUri: serviceUri,
    devToolsUri: devToolsUri,
  );
}

bool _isVmServiceLine(String line) =>
    line.startsWith('The Dart VM service is listening on ') ||
    line.startsWith('The Dart DevTools debugger and profiler is available at:');

String wsUriFromHttpUri(String httpUri) {
  final uri = Uri.parse(httpUri.trim());
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  var path = uri.path;
  if (!path.endsWith('/')) path = '$path/';
  return uri.replace(scheme: scheme, path: '${path}ws').toString();
}
