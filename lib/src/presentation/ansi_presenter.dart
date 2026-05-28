import 'dart:async';
import 'dart:io';

import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as p;

import '../domain/events.dart';
import 'presenter.dart';

class AnsiPresenter implements Presenter {
  final String cwd;
  final IOSink _out;

  StreamSubscription<RunnerEvent>? _sub;
  String? _pendingHeader;

  AnsiPresenter({String? cwd, IOSink? out})
      : cwd = cwd ?? Directory.current.path,
        _out = out ?? stdout;

  @override
  void attach(Stream<RunnerEvent> events) {
    _sub = events.listen(_render);
  }

  @override
  Future<void> dispose() async => _sub?.cancel();

  void _render(RunnerEvent e) {
    switch (e) {
      case RunnerStarted():
        _header('wait to watch changes...', Color.green);
      case CompileStarted(:final trigger):
        _pendingHeader = 'reloading ${_rel(trigger)}';
      case CompileSucceeded(:final elapsed):
        if (_pendingHeader != null) {
          _header(_pendingHeader!, Color.green);
          _pendingHeader = null;
        }
        _footer('compiled in ${elapsed.inMilliseconds}ms', Color.brightBlack);
      case CompileFailed(:final stderr):
        _pendingHeader = null;
        _header('compilation failed', Color.red);
        _out.writeln(stderr);
      case ReloadSucceeded(:final kind):
        _footer('${kind.name} ok', Color.green);
      case ReloadFailed(:final reason):
        _footer('reload failed: $reason', Color.red);
      case RunnerStopped():
        return;
    }
  }

  String _rel(String path) =>
      path.startsWith(cwd) ? p.relative(path, from: cwd) : path;

  void _header(String msg, Color color) {
    _out.writeAnsiAll([
      const CursorPosition.moveTo(0, 0),
      Clear.afterCursor,
      Clear.allAndScrollback,
      SetStyles(Style.foreground(color)),
      Print('[hmr] $msg'),
      SetStyles.reset,
      AsciiControl.lineFeed,
    ]);
  }

  void _footer(String msg, Color color) {
    _out.writeAnsiAll([
      SetStyles(Style.foreground(color)),
      Print('       $msg'),
      SetStyles.reset,
      AsciiControl.lineFeed,
    ]);
  }
}
