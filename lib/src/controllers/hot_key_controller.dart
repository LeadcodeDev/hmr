import 'dart:async';
import 'dart:io';

enum HotKey {
  reload,
  restart,
  quit,
  ctrlC,
  help,
  clear,
}

/// Reads raw stdin bytes and emits [HotKey] values for the keys we bind.
///
/// On [start] the terminal is switched to raw mode (echo + line buffering
/// disabled) so single keypresses arrive immediately. On [stop] the original
/// modes are restored — failing to do so leaves the terminal unusable, so the
/// restoration is guaranteed even when the input stream errors.
class HotKeyController {
  final Stream<List<int>> _input;
  final void Function(bool enabled) _setRawMode;

  StreamSubscription<List<int>>? _sub;
  final StreamController<HotKey> _keys = StreamController<HotKey>.broadcast();
  bool _started = false;
  bool _stopped = false;

  HotKeyController({
    Stream<List<int>>? input,
    void Function(bool enabled)? setRawMode,
  })  : _input = input ?? stdin,
        _setRawMode = setRawMode ?? _defaultSetRawMode;

  Stream<HotKey> get keys => _keys.stream;

  void start() {
    if (_started || _stopped) return;
    _started = true;
    _setRawMode(true);
    _sub = _input.listen(
      _onBytes,
      onError: (_, __) {/* swallow — stop() restores the terminal */},
      cancelOnError: false,
    );
  }

  void _onBytes(List<int> bytes) {
    for (final b in bytes) {
      final key = _map(b);
      if (key != null) _keys.add(key);
    }
  }

  static HotKey? _map(int byte) => switch (byte) {
        0x72 => HotKey.reload, // r
        0x52 => HotKey.restart, // R (shift+r)
        0x71 => HotKey.quit, // q
        0x03 => HotKey.ctrlC, // Ctrl+C
        0x68 => HotKey.help, // h
        0x63 => HotKey.clear, // c
        _ => null,
      };

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _sub?.cancel();
    _sub = null;
    if (_started) _setRawMode(false);
    await _keys.close();
  }

  static void _defaultSetRawMode(bool enabled) {
    try {
      stdin.echoMode = !enabled;
      stdin.lineMode = !enabled;
    } catch (_) {
      // Not a TTY (e.g. piped stdin) — silently degrade. Keys won't fire but
      // the rest of the system stays alive.
    }
  }
}
