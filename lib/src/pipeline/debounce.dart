import 'dart:async';

StreamTransformer<T, T> debounceTrailing<T>(Duration delay) {
  return StreamTransformer<T, T>.fromBind((source) {
    final out = StreamController<T>();
    Timer? timer;
    T? pending;
    var hasPending = false;

    source.listen(
      (event) {
        pending = event;
        hasPending = true;
        timer?.cancel();
        timer = Timer(delay, () {
          if (hasPending) {
            out.add(pending as T);
            hasPending = false;
            pending = null;
          }
        });
      },
      onError: out.addError,
      onDone: () {
        timer?.cancel();
        if (hasPending) out.add(pending as T);
        out.close();
      },
      cancelOnError: false,
    );

    return out.stream;
  });
}
