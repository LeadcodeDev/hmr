import 'package:hmr/src/domain/events.dart';
import 'package:hmr/src/runtime/hmr_runtime.dart';
import 'package:test/test.dart';

void main() {
  late Hmr hmr;

  setUp(() => hmr = Hmr.forTesting());

  group('on<E>', () {
    test('routes events by exact type', () {
      final received = <RunnerEvent>[];
      hmr.on<ReloadSucceeded>(received.add);

      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotReload));
      hmr.dispatch(RunnerStarted(DateTime.now()));

      expect(received, hasLength(1));
      expect(received.single, isA<ReloadSucceeded>());
    });

    test('on<RunnerEvent> receives every event', () {
      final received = <RunnerEvent>[];
      hmr.on<RunnerEvent>(received.add);

      hmr.dispatch(RunnerStarted(DateTime.now()));
      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotReload));
      hmr.dispatch(RunnerStopped(DateTime.now()));

      expect(received, hasLength(3));
    });

    test('multiple handlers for the same type all fire', () {
      var a = 0;
      var b = 0;
      hmr.on<RunnerStarted>((_) => a++);
      hmr.on<RunnerStarted>((_) => b++);

      hmr.dispatch(RunnerStarted(DateTime.now()));

      expect(a, 1);
      expect(b, 1);
    });
  });

  group('onReload / onRestart', () {
    test('onReload fires only for hotReload', () {
      final received = <ReloadSucceeded>[];
      hmr.onReload(received.add);

      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotReload));
      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotRestart));

      expect(received, hasLength(1));
      expect(received.single.kind, ReloadKind.hotReload);
    });

    test('onRestart fires only for hotRestart', () {
      final received = <ReloadSucceeded>[];
      hmr.onRestart(received.add);

      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotReload));
      hmr.dispatch(ReloadSucceeded(DateTime.now(), ReloadKind.hotRestart));

      expect(received, hasLength(1));
      expect(received.single.kind, ReloadKind.hotRestart);
    });
  });

  group('file event helpers', () {
    test('onFileCreated unwraps FsCreated from FileChanged', () {
      final received = <FsCreated>[];
      hmr.onFileCreated(received.add);

      final at = DateTime.now();
      hmr.dispatch(FileChanged(at, FsCreated('/a.dart', at)));
      hmr.dispatch(FileChanged(at, FsDeleted('/b.dart', at)));

      expect(received, hasLength(1));
      expect(received.single.path, '/a.dart');
    });

    test('onFileModified unwraps FsModified', () {
      final received = <FsModified>[];
      hmr.onFileModified(received.add);

      final at = DateTime.now();
      hmr.dispatch(FileChanged(at, FsModified('/a.dart', at)));
      hmr.dispatch(FileChanged(at, FsCreated('/b.dart', at)));

      expect(received, hasLength(1));
      expect(received.single.path, '/a.dart');
    });

    test('onFileDeleted unwraps FsDeleted', () {
      final received = <FsDeleted>[];
      hmr.onFileDeleted(received.add);

      final at = DateTime.now();
      hmr.dispatch(FileChanged(at, FsDeleted('/a.dart', at)));
      hmr.dispatch(FileChanged(at, FsCreated('/b.dart', at)));

      expect(received, hasLength(1));
      expect(received.single.path, '/a.dart');
    });

    test('onFileMoved unwraps FsMoved and exposes "to"', () {
      final received = <FsMoved>[];
      hmr.onFileMoved(received.add);

      final at = DateTime.now();
      hmr.dispatch(FileChanged(at, FsMoved('/old.dart', at, to: '/new.dart')));

      expect(received, hasLength(1));
      expect(received.single.path, '/old.dart');
      expect(received.single.to, '/new.dart');
    });
  });

  group('error isolation', () {
    test('a throwing handler does not prevent later handlers', () {
      var fired = false;
      hmr.on<RunnerStarted>((_) => throw StateError('boom'));
      hmr.on<RunnerStarted>((_) => fired = true);

      hmr.dispatch(RunnerStarted(DateTime.now()));

      expect(fired, isTrue);
    });
  });

  group('isActive', () {
    test('false by default in tests (no HMR_PARENT_PID)', () {
      expect(Hmr.forTesting().isActive, isFalse);
    });
  });
}
