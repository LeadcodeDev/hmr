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
- `bin/custom_hmr.dart` — a custom HMR runner built from the library's
  building blocks (strategy + watcher + filters + presenter). Copy this as
  a starting point when the bundled `hmr` CLI doesn't expose what you need.
- `lib/counter.dart`, `lib/formatter.dart` — library code reloaded on save.
- `tool/shape_change.dart` — script that mutates `Counter`'s shape to
  exercise the hot-restart fallback.

## Custom runner

```sh
dart run bin/custom_hmr.dart
```

Same hot-reload behaviour as `dart run hmr`, but with a tiny inline
`Presenter` that prefixes every event with a timestamp. Use it as a
template for your own output format, custom hot keys, alternate file
watcher, etc.
