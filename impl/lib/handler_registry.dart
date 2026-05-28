/// Holds named callbacks that can be replaced during a hot reload.
///
/// Handlers are re-registered after each reload, so their closures always
/// capture the latest code (even when they can't capture new state).
class HandlerRegistry {
  final Map<String, void Function()> _handlers = {};

  void register(String name, void Function() handler) {
    _handlers[name] = handler;
  }

  void invoke(String name) => _handlers[name]?.call();

  List<String> get names => List.unmodifiable(_handlers.keys);
}
