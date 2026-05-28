import 'dart:async';
import 'dart:io';

import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as p;

import '../domain/events.dart';

class AnsiPresenter {
  final String cwd;
  final IOSink _out;

  StreamSubscription<RunnerEvent>? _sub;

  AnsiPresenter({String? cwd, IOSink? out})
      : cwd = cwd ?? Directory.current.path,
        _out = out ?? stdout;

  void attach(Stream<RunnerEvent> events) {
    _sub = events.listen(_render);
  }

  Future<void> dispose() async => _sub?.cancel();

  void _render(RunnerEvent e) {
    switch (e) {
      case RunnerStarted():
        _header('wait to watch changes...', Color.green);
      case CompileStarted(:final trigger):
        _header('reloading ${_rel(trigger)}', Color.green);
      case CompileSucceeded(:final elapsed):
        _footer('compiled in ${elapsed.inMilliseconds}ms', Color.brightBlack);
      case CompileFailed(:final stderr):
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
