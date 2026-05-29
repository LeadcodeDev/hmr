# 🚀 Hot Module Replacement for Dart Applications

**HMR Dart** brings Flutter-grade hot reload to command-line Dart applications.

It runs your program as a child process attached to the Dart VM service, then
patches code in place on every save — without restarting the process, without
losing in-memory state, and without you wiring anything up.

## Highlights

| Feature                          | Description                                                                  |
|----------------------------------|------------------------------------------------------------------------------|
| 🪄 Zero configuration            | `dart pub global activate hmr` then `hmr` — that's it                        |
| ⚡ True hot reload                | Patches the running isolate via the VM service; state is preserved           |
| 🔁 Automatic full-restart fallback | Shape changes (new fields, etc.) silently fall back to a full restart        |
| ⌨️ Hot keys                      | `r` reload · `R` restart · `c` clear · `h` help · `q` quit                   |
| 🧠 Typed runtime API              | Opt into `package:hmr/runtime.dart` to react to events from inside your app  |
| 🎯 Targeted file watching         | Glob `includes` / `excludes` configured in `pubspec.yaml`                    |
| 🧾 Structured output              | `--format=json` for one JSON event per line — pipeable into anything         |
| 💥 Crash visibility               | Child stack traces are surfaced verbatim — no truncation, ever               |

## Install

```sh
dart pub global activate hmr
```

## Run

From the root of any Dart project:

```sh
hmr
```

That's the 80% case. By default, `hmr` watches `**/*.dart` from the current
directory and runs `bin/<package>.dart` (or `bin/main.dart`).

### Configuration (optional)

Add an `hmr` section to your `pubspec.yaml`:

```yaml
hmr:
  # Override the entrypoint path
  entrypoint: bin/server.dart

  # Debounce file events (ms). Defaults to 0 — immediate.
  debounce: 50

  # Only watch files matching these globs (defaults to **.dart)
  includes:
    - '**/*.dart'
    - 'config/*.yaml'

  # Ignore files matching these globs
  excludes:
    - 'test/**'
```

The entrypoint is resolved with the following priority:

1. CLI argument (positional)
2. `hmr.entrypoint` in `pubspec.yaml`
3. `bin/<package-name>.dart`
4. `bin/main.dart`

### CLI options

```
-f, --format     Output format: "ansi" (default) or "json"
-h, --help       Show usage
```

App arguments can be passed after `--`:

```sh
hmr -- --port 8080 --verbose
```

## Runtime API

For the 20% case — when your app needs to react to reloads (re-register
handlers, invalidate caches, etc.) — import `package:hmr/runtime.dart`:

```dart
import 'package:hmr/runtime.dart';

void main(List<String> args) {
  Hmr.instance.init();

  Hmr.instance.onReload((event) {
    print('Code reloaded (${event.kind})');
  });

  Hmr.instance.onFileModified((event) {
    print('Saved: ${event.path}');
  });

  // ... your app
}
```

The runtime is a no-op outside of `hmr` (detected via the `HMR_PARENT_PID`
environment variable), so the same `main()` works for both `hmr` and
`dart run`.

Available handlers:

- `on<E extends RunnerEvent>(handler)` — catch-all by type
- `onReload`, `onRestart` — split by `ReloadKind.hotReload` / `hotRestart`
- `onFileCreated`, `onFileModified`, `onFileDeleted`, `onFileMoved`

## Example

See [`example/`](example/) for a runnable demo:

```sh
cd example
dart pub get
dart run hmr
```

Edit `lib/counter.dart` or `lib/formatter.dart` and watch the ticking counter
update in place. Run `dart tool/shape_change.dart` to exercise the
hot-restart fallback.

## Events (JSON format)

With `--format=json` each line is a self-contained JSON object:

| `event`           | Fields                       |
|-------------------|------------------------------|
| `started`         | `ts`                         |
| `compileStarted`  | `ts`, `trigger`              |
| `compileSucceeded`| `ts`, `elapsedMs`            |
| `compileFailed`   | `ts`, `stderr`               |
| `reloadSucceeded` | `ts`, `kind`                 |
| `reloadFailed`    | `ts`, `reason`               |
| `fileChanged`     | `ts`, `event` (FsEvent)      |
| `processCrashed`  | `ts`, `exitCode`, `stderr`   |
| `stopped`         | `ts`                         |

## License

MIT
