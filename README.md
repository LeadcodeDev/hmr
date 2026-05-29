# 🚀 Hot Module Replacement for Dart Applications

**HMR Dart** brings Flutter-grade hot reload to command-line Dart applications.

It runs your program as a child process attached to the Dart VM service, then
patches code in place on every save — without restarting the process, without
losing in-memory state, and without you wiring anything up.

## Highlights

| Feature                            | Description                                                                  |
|------------------------------------|------------------------------------------------------------------------------|
| 🪄 Zero configuration              | `dart pub global activate hmr` then `hmr` — that's it                        |
| ⚡ True hot reload                  | Patches the running isolate via the VM service; state is preserved           |
| 🔁 Automatic full-restart fallback | Shape changes (new fields, etc.) silently fall back to a full restart        |
| ⌨️ Hot keys                        | `r` reload · `R` restart · `c` clear · `h` help · `q` quit                   |
| 🧠 Typed runtime API               | Opt into `package:hmr/runtime.dart` to react to events from inside your app  |
| 🧩 Composable library              | Build your own runner from `RunStrategy` + `FileWatcher` + `Presenter`       |
| 🎯 Targeted file watching          | Glob `includes` / `excludes` configured in `pubspec.yaml`                    |
| 🧾 Structured output               | `--format=json` for one JSON event per line — pipeable into anything         |
| 💥 Crash visibility                | Child stack traces are surfaced verbatim — no truncation, ever               |

## Contents

- [Install](#install)
- [Usage modes](#usage-modes)
  - [1. Built-in CLI (zero-config)](#1-built-in-cli-zero-config)
  - [2. Runtime API (in-app hooks)](#2-runtime-api-in-app-hooks)
  - [3. Custom runner (build your own)](#3-custom-runner-build-your-own)
- [Configuration reference](#configuration-reference)
  - [`pubspec.yaml` (`hmr:` block)](#pubspecyaml-hmr-block)
  - [CLI flags](#cli-flags)
  - [Runtime API](#runtime-api)
  - [Custom runner — building blocks](#custom-runner--building-blocks)
- [Events (JSON format)](#events-json-format)
- [License](#license)

## Install

```sh
dart pub global activate hmr
```

This puts the `hmr` executable on your PATH. Alternatively, add the package
to your `pubspec.yaml` and run it as `dart run hmr`:

```yaml
dev_dependencies:
  hmr: ^2.0.0
```

## Usage modes

### 1. Built-in CLI (zero-config)

From any Dart project root:

```sh
hmr
```

That covers the 80% case. `hmr` watches `**/*.dart` from the current
directory and launches `bin/<package>.dart` (or `bin/main.dart`). Save a
file, see the change live, state preserved.

App arguments go after `--`:

```sh
hmr -- --port 8080 --verbose
```

### 2. Runtime API (in-app hooks)

When your app needs to react to reloads (re-register handlers, invalidate
caches, re-open connections, etc.), import `package:hmr/runtime.dart` from
**your own** `main.dart`:

```dart
import 'package:hmr/runtime.dart';

void main(List<String> args) {
  Hmr.instance.init();

  Hmr.instance.onReload((e) {
    print('Code reloaded — handlers still valid');
  });

  Hmr.instance.onRestart((e) {
    print('Restarted — re-warming caches');
  });

  Hmr.instance.onFileModified((change) {
    print('Saved: ${change.path}');
  });

  // ... your app starts here
}
```

The runtime is a no-op outside `hmr` (detected via the `HMR_PARENT_PID`
environment variable), so the same `main()` works for both `hmr` and
plain `dart run`. No conditional imports, no production-build flags.

### 3. Custom runner (build your own)

When you need behaviour the built-in CLI doesn't expose — a custom output
format, alternate file watcher, extra hot keys, integration with an
existing supervisor — compose the library directly:

```dart
import 'dart:io';
import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final root = Directory.current.path;

  final strategy = VmServiceProcessStrategy(
    entrypoint: File(p.join(root, 'bin', 'main.dart')),
    args: args,
  );

  final orchestrator = ReloadOrchestrator(
    strategy: strategy,
    watcher: FileWatcher(root),
    filters: [
      ignoreSegment(const ['.git', '.dart_tool']),
      includeGlobs([Glob(p.join(root, '**.dart'))]),
    ],
    debounce: const Duration(milliseconds: 50),
  );

  // Bring your own presenter, or use AnsiPresenter / JsonPresenter.
  final presenter = AnsiPresenter()..attach(orchestrator.events);

  ProcessSignal.sigint.watch().listen((_) async {
    await orchestrator.stop();
    await presenter.dispose();
    exit(0);
  });

  await orchestrator.start();
}
```

A fully-fleshed example (with hot keys + a custom timestamped presenter)
lives at [`example/bin/custom_hmr.dart`](example/bin/custom_hmr.dart).

## Configuration reference

### `pubspec.yaml` (`hmr:` block)

Every field is optional. With no `hmr:` block at all, defaults apply.

```yaml
hmr:
  entrypoint: bin/server.dart
  debounce: 50
  includes:
    - '**/*.dart'
    - 'config/*.yaml'
  excludes:
    - 'test/**'
    - 'doc/**'
```

| Field        | Type           | Default                         | Description                                                                                                  |
|--------------|----------------|---------------------------------|--------------------------------------------------------------------------------------------------------------|
| `entrypoint` | `String`       | `bin/<package>.dart` then `bin/main.dart` | Path (relative to project root) to the Dart file `hmr` runs.                                       |
| `debounce`   | `int` (ms)     | `0`                             | Coalesce file-system events within this window into a single reload. Must be `>= 0`.                         |
| `includes`   | `List<String>` | `['**.dart']`                   | Glob patterns; a file change only triggers a reload if it matches at least one include.                      |
| `excludes`   | `List<String>` | `[]` (plus built-in ignores)    | Glob patterns; matching files are dropped even if `includes` would accept them.                              |

**Entrypoint resolution priority** (highest wins):

1. Positional CLI argument (reserved — not currently exposed)
2. `hmr.entrypoint` in `pubspec.yaml`
3. `bin/<package-name>.dart`
4. `bin/main.dart`

`hmr` always ignores `.git`, `.dart_tool`, `.idea`, `.vscode`, and `~`
regardless of `includes` / `excludes`.

Globs use the [`glob`](https://pub.dev/packages/glob) package syntax. They
are anchored at the project root, so `lib/**.dart` matches `lib/a.dart`
and `lib/sub/b.dart`.

### CLI flags

```
-f, --format     Output format: "ansi" (default) or "json"
-h, --help       Show usage
```

Arguments after `--` are forwarded to the child process verbatim.

### Runtime API

`package:hmr/runtime.dart` exports the `Hmr` singleton and the event
sealed-class hierarchy.

```dart
import 'package:hmr/runtime.dart';

Hmr.instance.init();
```

| Member                                       | Purpose                                                                 |
|----------------------------------------------|-------------------------------------------------------------------------|
| `Hmr.instance`                               | Process-wide singleton.                                                  |
| `Hmr.forTesting()`                           | Fresh isolated instance for unit tests.                                  |
| `bool isActive`                              | `true` when launched by the `hmr` supervisor (`HMR_PARENT_PID` set).     |
| `void init()`                                | Registers the VM service extension. Idempotent. No-op outside `hmr`.     |
| `void on<E extends RunnerEvent>(handler)`    | Catch-all by event type. `on<RunnerEvent>(…)` receives every event.      |
| `void onReload(handler)`                     | Fires after a successful hot reload (`ReloadKind.hotReload`).            |
| `void onRestart(handler)`                    | Fires after a successful hot restart (`ReloadKind.hotRestart`).          |
| `void onFileCreated(handler)`                | Fires for each `FsCreated` file event.                                   |
| `void onFileModified(handler)`               | Fires for each `FsModified` file event.                                  |
| `void onFileDeleted(handler)`                | Fires for each `FsDeleted` file event.                                   |
| `void onFileMoved(handler)`                  | Fires for each `FsMoved` file event.                                     |

Handler exceptions are caught and logged to stderr — a buggy hook never
crashes your app.

### Custom runner — building blocks

Import `package:hmr/hmr.dart` to get the composable pieces.

| Symbol                                       | Role                                                                          |
|----------------------------------------------|-------------------------------------------------------------------------------|
| `VmServiceProcessStrategy`                   | Launches the entrypoint as a child process, owns the VM service connection.  |
| `RunStrategy` (interface)                    | Implement to replace the strategy entirely.                                   |
| `FileWatcher(root)`                          | Recursive file-system watcher emitting `FsEvent`s.                            |
| `ignoreSegment(List<String>)`                | Filter: drop events whose path contains any forbidden path segment.           |
| `includeGlobs(List<Glob>)`                   | Filter: keep events matching at least one glob.                               |
| `excludeGlobs(List<Glob>)`                   | Filter: drop events matching any glob.                                        |
| `ReloadOrchestrator`                         | Wires strategy + watcher + filters + debounce. Exposes `start/stop/reload/restart`. |
| `AnsiPresenter`                              | Default human-readable terminal output.                                       |
| `JsonPresenter`                              | One JSON object per event line (same schema as `--format=json`).              |
| `Presenter` (interface)                      | Implement `attach(Stream<RunnerEvent>)` + `dispose()` for custom output.      |
| `HotKeyController`                           | Reads raw stdin, emits `HotKey` enum values. Injectable input + raw-mode fn. |
| `EntrypointResolver`                         | Reusable entrypoint resolution (CLI → config → conventions).                  |
| `Config.of(YamlMap)`                         | Parse + validate the `hmr:` pubspec block. Throws `ConfigError` on bad input. |

`ReloadOrchestrator` constructor:

```dart
ReloadOrchestrator({
  required RunStrategy strategy,
  required FileWatcher watcher,
  List<FsFilter> filters = const [],
  Duration debounce = Duration.zero,
});
```

`VmServiceProcessStrategy` constructor:

```dart
VmServiceProcessStrategy({
  required File entrypoint,
  List<String> args = const [],
  VmServiceLauncherFn? launcher, // override for tests
});
```

## Events (JSON format)

With `--format=json` each line is a self-contained JSON object. Every
event carries `event` (the discriminator) and `ts` (milliseconds since
epoch).

| `event`           | Extra fields                                                  |
|-------------------|---------------------------------------------------------------|
| `started`         | —                                                             |
| `fileChanged`     | `change` (FsEvent: `kind`, `path`, `at`, optional `to`)       |
| `compileStarted`  | `trigger`, optional `fileEvent`                               |
| `compileSucceeded`| `elapsedMs`                                                   |
| `compileFailed`   | `stderr`                                                      |
| `reloadSucceeded` | `kind` (`hotReload` or `hotRestart`)                          |
| `reloadFailed`    | `reason`                                                      |
| `processCrashed`  | `exitCode`, `stderr` (verbatim, no truncation)                |
| `stopped`         | —                                                             |

`FsEvent.kind` is one of `created`, `modified`, `deleted`, `moved`.
`moved` events additionally carry a `to` field with the destination path.

Runtime-API handlers receive deserialized `RunnerEvent` objects of the
matching sealed class — you never parse JSON yourself.

## License

MIT
