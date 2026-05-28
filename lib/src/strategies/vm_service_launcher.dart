import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/vm_service.dart';

/// Spawns a Dart child process with the VM service enabled and connects to it.
///
/// Returns `(process, service, stderrLines)` where `stderrLines` is a broadcast
/// stream of all stderr text lines from the child (including post-URI output).
Future<(Process, VmService, Stream<String>)> launchWithVmService(
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
  );

  final stderrController = StreamController<String>.broadcast();
  final uriCompleter = Completer<String>();
  final uriPattern = RegExp(r'listening on (https?://\S+)');

  void tryComplete(String line) {
    if (!uriCompleter.isCompleted) {
      final match = uriPattern.firstMatch(line);
      if (match != null) {
        uriCompleter.complete(wsUriFromHttpUri(match.group(1)!));
      }
    }
  }

  // Dart 3.8+ prints the VM service URI to stdout; earlier versions used
  // stderr. Scan both so we handle either runtime. VM service info lines
  // are suppressed from terminal output since HMR owns the process lifecycle.
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        tryComplete(line);
        if (!_isVmServiceLine(line)) stdout.writeln(line);
      });

  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          tryComplete(line);
          if (!_isVmServiceLine(line)) stderrController.add(line);
        },
        onError: (Object e, StackTrace st) {
          stderrController.addError(e, st);
          if (!uriCompleter.isCompleted) uriCompleter.completeError(e, st);
        },
        onDone: () {
          stderrController.close();
          if (!uriCompleter.isCompleted) {
            uriCompleter.completeError(
              StateError('VM service URI not found in child process output'),
            );
          }
        },
      );

  final wsUri = await uriCompleter.future;
  final service = await vmServiceConnectUri(wsUri);

  return (process, service, stderrController.stream);
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
