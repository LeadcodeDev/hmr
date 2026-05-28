# hmr example

A minimal CLI app demonstrating `hmr` hot reload.

## Run

From this directory:

```sh
dart pub get
dart run hmr
```

Edit `lib/counter.dart` or `lib/formatter.dart` and save — the running
process picks up the change in milliseconds.

## Layout

- `bin/main.dart` — entrypoint, prints a ticking counter.
- `lib/counter.dart`, `lib/formatter.dart`, `lib/handler_registry.dart` —
  library code reloaded on save.
- `tool/shape_change.dart` — script that mutates `Counter`'s shape to
  exercise the hot-restart fallback.
