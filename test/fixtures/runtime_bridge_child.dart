import 'dart:convert';
import 'dart:io';

import 'package:hmr/runtime.dart';

/// Fixture for runtime_bridge_e2e_test.
///
/// Initialises the [Hmr] runtime, registers a catch-all handler that appends
/// every received event as JSON to the marker file passed as argv[0], and
/// stays alive long enough for the parent to dispatch.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('runtime_bridge_child: marker file path required');
    exit(64);
  }
  final marker = File(args[0]);
  marker.writeAsStringSync('');

  Hmr.instance.on<RunnerEvent>((event) {
    marker.writeAsStringSync(
      '${jsonEncode(event.toJson())}\n',
      mode: FileMode.append,
    );
  });
  Hmr.instance.init();

  // Stay alive — the parent kills us when it's done.
  await Future<void>.delayed(const Duration(minutes: 2));
}
