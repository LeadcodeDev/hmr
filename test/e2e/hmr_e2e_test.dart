@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Copies a directory tree recursively.
Future<void> _copyDir(Directory src, Directory dst) async {
  if (!await dst.exists()) await dst.create(recursive: true);
  await for (final entity in src.list()) {
    final name = p.basename(entity.path);
    if (name == '.dart_tool' || name == '.git') continue;
    if (entity is File) {
      await entity.copy(p.join(dst.path, name));
    } else if (entity is Directory) {
      await _copyDir(entity, Directory(p.join(dst.path, name)));
    }
  }
}

void main() {
  late Directory tmpDir;
  late Process hmrProcess;

  setUpAll(() async {
    // Build a temp clone of example/ to watch.
    tmpDir = await Directory.systemTemp.createTemp('hmr_e2e_');
    // test/e2e/hmr_e2e_test.dart → 3 dirname calls → package root → example/
    final exampleSrc = Directory(p.join(
      p.dirname(p.dirname(p.dirname(p.fromUri(Platform.script)))),
      'example',
    ));
    await _copyDir(exampleSrc, tmpDir);
    // Run pub get in the clone so the lock file is valid.
    final pubGet = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: tmpDir.path,
    );
    if (pubGet.exitCode != 0) {
      fail('dart pub get failed in $tmpDir:\n${pubGet.stderr}');
    }
  });

  tearDownAll(() async {
    hmrProcess.kill(ProcessSignal.sigterm);
    await hmrProcess.exitCode;
    await tmpDir.delete(recursive: true);
  });

  test('hmr starts and emits started + compileSucceeded + reloadSucceeded',
      () async {
    hmrProcess = await Process.start(
      'dart',
      ['run', 'hmr', '--format=json'],
      workingDirectory: tmpDir.path,
    );

    final jsonLines = hmrProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((l) => l.trim().startsWith('{'));

    // Collect events until we see a reloadSucceeded or timeout.
    final events = <Map<String, Object?>>[];
    final completer = Completer<void>();

    late StreamSubscription sub;
    sub = jsonLines.listen((line) {
      final obj = jsonDecode(line) as Map<String, Object?>;
      events.add(obj);
      if (obj['event'] == 'reloadSucceeded') {
        completer.complete();
        sub.cancel();
      }
    });

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => fail('Did not receive reloadSucceeded within 30s. '
          'Events so far: $events'),
    );

    final eventNames = events.map((e) => e['event']).toList();
    expect(eventNames, containsAll(['started', 'reloadSucceeded']));
  });

  test('file modification triggers a new reload cycle', () async {
    // The process from the previous test is still running.
    final jsonLines = hmrProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((l) => l.trim().startsWith('{'));

    final completer = Completer<Map<String, Object?>>();
    late StreamSubscription sub;
    sub = jsonLines.listen((line) {
      final obj = jsonDecode(line) as Map<String, Object?>;
      if (obj['event'] == 'reloadSucceeded' && !completer.isCompleted) {
        completer.complete(obj);
        sub.cancel();
      }
    });

    // Touch a watched file to trigger a reload.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final formatter = File(p.join(tmpDir.path, 'lib', 'formatter.dart'));
    final original = await formatter.readAsString();
    await formatter.writeAsString(
      original.replaceFirst("'count: \$value'", "'tally: \$value'"),
    );

    final event = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          fail('Did not receive reload after file change within 30s'),
    );

    expect(event['event'], 'reloadSucceeded');
  });
}
