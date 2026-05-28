import 'dart:async';

import 'package:hmr/src/controllers/hot_key_controller.dart';
import 'package:test/test.dart';

void main() {
  late StreamController<List<int>> input;
  late List<bool> rawModeCalls;
  late HotKeyController controller;

  setUp(() {
    input = StreamController<List<int>>.broadcast();
    rawModeCalls = [];
    controller = HotKeyController(
      input: input.stream,
      setRawMode: rawModeCalls.add,
    );
  });

  tearDown(() async {
    await controller.stop();
    await input.close();
  });

  test('start enables raw mode and stop restores it', () async {
    controller.start();
    expect(rawModeCalls, [true]);

    await controller.stop();
    expect(rawModeCalls, [true, false]);
  });

  test('maps single-byte keys to HotKey values', () async {
    controller.start();
    final received = <HotKey>[];
    final sub = controller.keys.listen(received.add);

    input.add([0x72]); // r
    input.add([0x52]); // R
    input.add([0x71]); // q
    input.add([0x68]); // h
    input.add([0x63]); // c
    input.add([0x03]); // Ctrl+C
    await Future<void>.delayed(Duration.zero);

    expect(received, [
      HotKey.reload,
      HotKey.restart,
      HotKey.quit,
      HotKey.help,
      HotKey.clear,
      HotKey.ctrlC,
    ]);

    await sub.cancel();
  });

  test('demultiplexes multi-byte chunks', () async {
    controller.start();
    final received = <HotKey>[];
    final sub = controller.keys.listen(received.add);

    input.add([0x72, 0x52, 0x71]); // r R q in one chunk
    await Future<void>.delayed(Duration.zero);

    expect(received, [HotKey.reload, HotKey.restart, HotKey.quit]);
    await sub.cancel();
  });

  test('unknown bytes are ignored', () async {
    controller.start();
    final received = <HotKey>[];
    final sub = controller.keys.listen(received.add);

    input.add([0x01, 0x7a, 0x41]); // not bound
    input.add([0x72]); // r — should still come through
    await Future<void>.delayed(Duration.zero);

    expect(received, [HotKey.reload]);
    await sub.cancel();
  });

  test('start is idempotent', () async {
    controller.start();
    controller.start();

    expect(rawModeCalls, [true], reason: 'raw mode toggled only once');
  });

  test('stop is idempotent and safe before start', () async {
    await controller.stop();
    await controller.stop();
    expect(rawModeCalls, isEmpty);
  });

  test('keys stream closes after stop', () async {
    controller.start();
    final done = controller.keys.drain<void>();
    await controller.stop();
    await done; // completes only when the stream closes
  });

  test('raw mode is restored even if the input stream throws', () async {
    controller.start();
    input.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);

    await controller.stop();
    expect(rawModeCalls.last, isFalse);
  });
}
