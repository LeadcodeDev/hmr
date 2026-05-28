import 'package:hmr/src/domain/events.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 5, 29, 10, 30, 45, 123);

  group('FsEvent JSON round-trip', () {
    test('FsCreated', () {
      final e = FsCreated('lib/a.dart', at);
      final back = FsEvent.fromJson(e.toJson());
      expect(back, isA<FsCreated>());
      expect(back.path, 'lib/a.dart');
      expect(back.at, at);
    });

    test('FsModified', () {
      final back = FsEvent.fromJson(FsModified('lib/b.dart', at).toJson());
      expect(back, isA<FsModified>());
    });

    test('FsDeleted', () {
      final back = FsEvent.fromJson(FsDeleted('lib/c.dart', at).toJson());
      expect(back, isA<FsDeleted>());
    });

    test('FsMoved carries to', () {
      final e = FsMoved('lib/old.dart', at, to: 'lib/new.dart');
      final back = FsEvent.fromJson(e.toJson()) as FsMoved;
      expect(back.path, 'lib/old.dart');
      expect(back.to, 'lib/new.dart');
    });

    test('FsMoved without to', () {
      final e = FsMoved('lib/gone.dart', at);
      final back = FsEvent.fromJson(e.toJson()) as FsMoved;
      expect(back.to, isNull);
    });

    test('throws on unknown kind', () {
      expect(
        () => FsEvent.fromJson({
          'kind': 'wat',
          'path': 'x',
          'at': at.toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });

  group('RunnerEvent JSON round-trip', () {
    test('RunnerStarted', () {
      final back = RunnerEvent.fromJson(RunnerStarted(at).toJson());
      expect(back, isA<RunnerStarted>());
      expect(back.at, at);
    });

    test('FileChanged carries the FsEvent', () {
      final e = FileChanged(at, FsCreated('lib/x.dart', at));
      final back = RunnerEvent.fromJson(e.toJson()) as FileChanged;
      expect(back.change, isA<FsCreated>());
      expect(back.change.path, 'lib/x.dart');
    });

    test('CompileStarted without fileEvent', () {
      final back =
          RunnerEvent.fromJson(CompileStarted(at, 'hotkey:r').toJson())
              as CompileStarted;
      expect(back.trigger, 'hotkey:r');
      expect(back.fileEvent, isNull);
    });

    test('CompileStarted with fileEvent', () {
      final e = CompileStarted(
        at,
        'lib/x.dart',
        fileEvent: FsModified('lib/x.dart', at),
      );
      final back = RunnerEvent.fromJson(e.toJson()) as CompileStarted;
      expect(back.fileEvent, isA<FsModified>());
      expect(back.fileEvent!.path, 'lib/x.dart');
    });

    test('CompileSucceeded preserves elapsed precisely', () {
      final e = CompileSucceeded(at, const Duration(microseconds: 12345678));
      final back = RunnerEvent.fromJson(e.toJson()) as CompileSucceeded;
      expect(back.elapsed.inMicroseconds, 12345678);
    });

    test('CompileFailed stderr is preserved verbatim (multiline)', () {
      const stderr = 'Error: bla\n  at foo.dart:1:1\n  at bar.dart:2:2';
      final back =
          RunnerEvent.fromJson(CompileFailed(at, stderr).toJson())
              as CompileFailed;
      expect(back.stderr, stderr);
    });

    test('ReloadSucceeded hotReload', () {
      final back = RunnerEvent.fromJson(
          ReloadSucceeded(at, ReloadKind.hotReload).toJson()) as ReloadSucceeded;
      expect(back.kind, ReloadKind.hotReload);
    });

    test('ReloadSucceeded hotRestart', () {
      final back = RunnerEvent.fromJson(
          ReloadSucceeded(at, ReloadKind.hotRestart).toJson()) as ReloadSucceeded;
      expect(back.kind, ReloadKind.hotRestart);
    });

    test('ReloadFailed', () {
      final back = RunnerEvent.fromJson(ReloadFailed(at, 'boom').toJson())
          as ReloadFailed;
      expect(back.reason, 'boom');
    });

    test('ProcessCrashed preserves exitCode and full stderr', () {
      final stack = List.generate(60, (i) => '#$i  frame_$i (file.dart:$i)')
          .join('\n');
      final back = RunnerEvent.fromJson(
              ProcessCrashed(at, 137, stack).toJson()) as ProcessCrashed;
      expect(back.exitCode, 137);
      expect(back.stderr, stack);
      expect(back.stderr.split('\n'), hasLength(60));
    });

    test('RunnerStopped', () {
      final back = RunnerEvent.fromJson(RunnerStopped(at).toJson());
      expect(back, isA<RunnerStopped>());
    });

    test('throws on unknown type', () {
      expect(
        () => RunnerEvent.fromJson({
          'type': 'bogus',
          'at': at.toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });
}
