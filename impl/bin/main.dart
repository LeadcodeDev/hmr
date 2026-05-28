import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:impl/counter.dart';
import 'package:impl/formatter.dart';
import 'package:impl/handler_registry.dart';

void main(List<String> args, [SendPort? port]) {
  final counter = Counter();
  final registry = HandlerRegistry();

  registry.register('tick', counter.increment);

  // Register ext.impl.rescan so IDEs and the --rescan-extension flag
  // can request a state reset without a full restart.
  registerExtension('ext.impl.rescan', (method, params) async {
    counter.reset();
    registry.invoke('reset');
    return ServiceExtensionResponse.result('{"reset": true}');
  });

  // Isolate restart strategy handshake.
  if (port != null) {
    final receivePort = ReceivePort();
    port.send(receivePort.sendPort);
    receivePort.listen((msg) {
      if (msg case {'__hmr__': 'shutdown'}) {
        receivePort.close();
        exit(0);
      }
    });
  }

  // Print the formatted counter and tick every 500ms.
  Timer.periodic(const Duration(milliseconds: 500), (_) {
    print(format(counter.value));
    registry.invoke('tick');
  });
}
