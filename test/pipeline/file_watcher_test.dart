import 'dart:io';

import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/pipeline/file_watcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('emits FsModified when a file is written', () async {
    final dir = await Directory.systemTemp.createTemp('hmr-fw-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'a.txt'));
    await file.writeAsString('hello');

    final fw = FileWatcher(dir.path);
    addTearDown(fw.dispose);

    final first = fw.stream
        .firstWhere((e) => e.path.endsWith('a.txt') && e is FsModified);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    await file.writeAsString('world');

    final event = await first.timeout(const Duration(seconds: 5));
    expect(event, isA<FsModified>());
  });

  test('emits FsCreated when a new file appears', () async {
    final dir = await Directory.systemTemp.createTemp('hmr-fw-');
    addTearDown(() => dir.delete(recursive: true));

    final fw = FileWatcher(dir.path);
    addTearDown(fw.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    final first =
        fw.stream.firstWhere((e) => e.path.endsWith('new.txt'));

    await File(p.join(dir.path, 'new.txt')).writeAsString('created');

    final event = await first.timeout(const Duration(seconds: 5));
    expect(event, isA<FsCreated>());
  });
}
