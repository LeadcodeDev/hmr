# Changelog

## 2.0.0

**Flutter-grade HMR for CLI Dart applications.** Major rewrite around the Dart
VM service: true hot reload (no recompilation pipeline, no isolate restart),
preserved app state, and a child-side runtime API for reacting to events.

### New

- `VmServiceProcessStrategy` — launches the entry point as a child process with
  `--enable-vm-service=0`, then issues `reloadSources` on file changes.
- Automatic fallback from hot reload to a full restart on shape changes.
- `package:hmr/runtime.dart` — opt-in `Hmr.instance` API for the child process
  to subscribe to typed events (`onReload`, `onRestart`, `onFileCreated`,
  `onFileModified`, `onFileDeleted`, `onFileMoved`, or a generic `on<E>`).
- Hot keys: `r` (reload), `R` (restart), `c` (clear), `h` (help), `q` (quit).
- Structured event model with JSON serialization (`--format=json`) covering
  `started`, `compileStarted`, `compileSucceeded`, `compileFailed`,
  `reloadSucceeded`, `reloadFailed`, `fileChanged`, `processCrashed`,
  `stopped`.
- `ProcessCrashed` preserves the full child stderr verbatim — no truncation.
- `EntrypointResolver` with a documented priority chain: CLI arg → pubspec
  `hmr.entrypoint` → `bin/<package>.dart` → `bin/main.dart`.

### Breaking

- Removed `IsolateRestartStrategy` and the `--strategy` flag — every run uses
  the VM-service strategy.
- Removed the `--rescan-extension` flag (use the runtime API instead).
- Renamed `impl/` to `example/` (pub.dev convention).
- Renamed `VmServiceReloadStrategy` → `VmServiceProcessStrategy`.

## 1.4.1

- remove `SIGTERM` on windows

## 1.4.0

- Expose `send` and `listen` methods
- Request `SendPort` from Isolate to send messages in the Isolate

## 1.3.2

- Change `debounce` middleware order

## 1.3.1

- Remove `debounce` delay by default

## 1.3.0

- Migrate filters to responsibility chain pattern

## 1.2.0

- Implement `debounce` delay
- Ignore `.dart_tool` and IDE directories by default

## 1.1.2

- Remove `ProcessSignal.SIGTERM`

## 1.1.1

- Fix entrypoint implicite extension

## 1.1.0

- Transfert `hmr [...args]` to `Isolate`

## 1.0.3

- Add newline on exit to prevent terminal prompt bad display

## 1.0.2

- Enforce clear screen on start
- Enforce clear screen on reload

## 1.0.1

- Prevent the `hmr` command from being run in a non-Dart project
- Add clean-up of temporary files on exit

## 1.0.0

**Initial Release** - Première publication officielle du package HMR pour Dart

- Hot reload without restarting the application
- State retention between reloads
- Automated kernel compilation via `dart compile`.

- Glob patterns for inclusion/exclusion (`**/*.dart`)
- Detection of modifications/creations/deletions/moves
- Configurable debounce mechanism

- Visual feedback with ANSI codes (colours, positioning)
- Own compile error handling
- Successive changes counter
