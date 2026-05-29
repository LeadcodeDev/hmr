import 'dart:async';
import 'dart:io';

import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as p;

import '../domain/events.dart';
import '../version.dart';
import 'presenter.dart';

class AnsiPresenter implements Presenter {
  static const Color _accent = Color.yellow;

  final String cwd;
  final IOSink _out;
  final bool showBanner;

  StreamSubscription<RunnerEvent>? _sub;
  String? _pendingTrigger;
  String? _lastTrigger;
  int _repeatCount = 0;

  AnsiPresenter({String? cwd, IOSink? out, this.showBanner = true})
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
      case RunnerStarted(
          :final elapsed,
          :final entrypoint,
          :final serviceUri,
          :final devToolsUri,
        ):
        if (showBanner) {
          unawaited(_banner(
            elapsed: elapsed,
            entrypoint: entrypoint,
            debugUri: devToolsUri ?? serviceUri,
          ));
        } else {
          _header('wait to watch changes...', Color.green);
        }
      case FileChanged():
        // Raw FS signal — handled by hooks/jsonpresenter, no visual noise here.
        return;
      case CompileStarted(
          :final at,
          :final trigger,
          :final fileEvent,
          :final kind,
        ):
        _pendingTrigger = trigger;
        if (trigger == _lastTrigger) {
          _repeatCount++;
        } else {
          _repeatCount = 1;
          _lastTrigger = trigger;
        }
        // Definitive line emitted at save-time — gives the user immediate
        // feedback even when the underlying VM reload takes seconds.
        _reloadLine(
            at, _actionLabel(fileEvent, trigger, kind), trigger, Color.green,
            count: _repeatCount);
      case CompileSucceeded():
        return;
      case CompileFailed(:final stderr):
        _pendingTrigger = null;
        _header('compilation failed', Color.red);
        _out.writeln(stderr);
      case ReloadSucceeded():
        _pendingTrigger = null;
      case ReloadFailed(:final at, :final reason):
        _reloadLine(
            at, 'error', _pendingTrigger, Color.red,
            suffix: reason, count: _repeatCount);
        _pendingTrigger = null;
      case ProcessCrashed(:final exitCode, :final stderr):
        _pendingTrigger = null;
        _header('process exited with code $exitCode', Color.red);
        _out.writeln(stderr);
        _footer(
            'fix the error and save, or press R to restart', Color.brightBlack);
      case RunnerStopped():
        return;
    }
  }

  String _rel(String path) =>
      path.startsWith(cwd) ? p.relative(path, from: cwd) : path;

  String _actionLabel(FsEvent? event, String? trigger, ReloadKind? kind) {
    // An explicit `hotRestart` hint from the strategy always wins — an
    // entrypoint update is technically a "modified" FsEvent but the user
    // sees a full restart, so the verb must reflect that.
    if (kind == ReloadKind.hotRestart) return 'hot restart';
    return switch (event) {
      FsCreated() => 'created',
      FsDeleted() => 'deleted',
      FsModified() || FsMoved() => 'update',
      null => trigger == 'hotkey:R' ? 'hot restart' : 'reload',
    };
  }

  String _fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  void _reloadLine(
    DateTime at,
    String action,
    String? trigger,
    Color actionColor, {
    String? suffix,
    int count = 1,
  }) {
    _out.writeAnsiAll([
      const CursorPosition.moveTo(0, 0),
      Clear.afterCursor,
      Clear.allAndScrollback,
      SetStyles(Style.foreground(Color.brightBlack)),
      Print(_fmtTime(at)),
      SetStyles.reset,
      Print(' '),
      SetStyles(Style.foreground(_accent)),
      Print('[hmr]'),
      SetStyles.reset,
      Print(' '),
      SetStyles(Style.foreground(actionColor)),
      Print(action),
      SetStyles.reset,
      if (trigger != null) ...[
        Print(' '),
        Print(_rel(trigger)),
      ],
      if (count > 1) ...[
        Print(' '),
        SetStyles(Style.foreground(Color.brightBlack)),
        Print('(x$count)'),
        SetStyles.reset,
      ],
      if (suffix != null) ...[
        Print(' '),
        SetStyles(Style.foreground(Color.red)),
        Print(suffix),
        SetStyles.reset,
      ],
      AsciiControl.lineFeed,
    ]);
  }

  Future<void> _banner({
    Duration? elapsed,
    String? entrypoint,
    String? debugUri,
  }) async {
    final version = await resolveHmrVersion();
    _out.writeAnsiAll([
      const CursorPosition.moveTo(0, 0),
      Clear.afterCursor,
      Clear.allAndScrollback,
    ]);
    _out.writeAnsiAll([
      Print('  '),
      SetStyles(Style.foreground(_accent), Style.bold),
      Print('HMR'),
      SetStyles.reset,
      Print('  '),
      SetStyles(Style.foreground(Color.brightBlack)),
      Print('v$version'),
      SetStyles.reset,
      if (elapsed != null) ...[
        Print('  '),
        SetStyles(Style.foreground(Color.brightBlack)),
        Print('ready in '),
        SetStyles.reset,
        SetStyles(Style.bold),
        Print('${elapsed.inMilliseconds} ms'),
        SetStyles.reset,
      ],
      AsciiControl.lineFeed,
      AsciiControl.lineFeed,
    ]);
    if (entrypoint != null) {
      _out.writeAnsiAll([
        Print('  '),
        SetStyles(Style.foreground(_accent)),
        Print('→'),
        SetStyles.reset,
        Print('  '),
        SetStyles(Style.bold),
        Print('Entrypoint:'),
        SetStyles.reset,
        Print('  '),
        SetStyles(Style.foreground(Color.cyan)),
        Print(_rel(entrypoint)),
        SetStyles.reset,
        AsciiControl.lineFeed,
      ]);
    }
    if (debugUri != null) {
      final parsed = Uri.tryParse(debugUri);
      final origin = parsed == null
          ? debugUri
          : '${parsed.scheme}://${parsed.host}:${parsed.port}';
      _out.writeAnsiAll([
        Print('  '),
        SetStyles(Style.foreground(_accent)),
        Print('→'),
        SetStyles.reset,
        Print('  '),
        SetStyles(Style.bold),
        Print('DevTools:  '),
        SetStyles.reset,
        Print(' '),
        SetStyles(Style.foreground(Color.cyan)),
      ]);
      // OSC 8 hyperlink: terminals that support it open `debugUri` on click
      // while still rendering `origin` as the visible text. Older terminals
      // silently ignore the escapes and print the origin as plain text.
      // Written raw because mansion's Print() escapes ESC bytes literally.
      _out.write('\x1B]8;;$debugUri\x1B\\$origin\x1B]8;;\x1B\\');
      _out.writeAnsiAll([
        SetStyles.reset,
        AsciiControl.lineFeed,
      ]);
    }
    _out.writeAnsiAll([
      Print('  '),
      SetStyles(Style.foreground(Color.yellow)),
      Print('→'),
      SetStyles.reset,
      Print('  '),
      SetStyles(Style.foreground(Color.brightBlack)),
      Print('press '),
      SetStyles.reset,
      SetStyles(Style.bold),
      Print('h'),
      SetStyles.reset,
      SetStyles(Style.foreground(Color.brightBlack)),
      Print(' to show help'),
      SetStyles.reset,
      AsciiControl.lineFeed,
      AsciiControl.lineFeed,
    ]);
  }

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
      Print('      $msg'),
      SetStyles.reset,
      AsciiControl.lineFeed,
    ]);
  }
}
