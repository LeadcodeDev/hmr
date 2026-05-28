import 'dart:async';

import '../domain/events.dart';
import '../pipeline/debounce.dart';
import '../pipeline/file_watcher.dart';
import '../pipeline/filters.dart';
import '../strategies/run_strategy.dart';

class ReloadOrchestrator {
  final RunStrategy strategy;
  final FileWatcher watcher;
  final List<FsFilter> filters;
  final Duration debounce;

  StreamSubscription<FsEvent>? _sub;

  ReloadOrchestrator({
    required this.strategy,
    required this.watcher,
    this.filters = const [],
    this.debounce = Duration.zero,
  });

  Stream<RunnerEvent> get events => strategy.events;

  Future<void> start() async {
    await strategy.start();

    Stream<FsEvent> stream = watcher.stream;
    for (final f in filters) {
      stream = stream.where(f);
    }
    if (debounce > Duration.zero) {
      stream = stream.transform(debounceTrailing(debounce));
    }
    _sub = stream.listen((e) => strategy.reload(trigger: e.path));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await watcher.dispose();
    await strategy.dispose();
  }
}
