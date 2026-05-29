# Changelog

## 2.1.0

Focus on perceived reload latency and terminal UX polish. No breaking
changes — existing 2.0.0 setups upgrade in place.

### New

- Smart default exclusions: when no `hmr.excludes` is set in `pubspec.yaml`,
  irrelevant noise (`test/`, `build/`, `doc(s)/`, `.git/`, `.idea/`,
  `.vscode/`, editor swap files, `.DS_Store`, …) is skipped to cut perceived
  reload time. Setting `hmr.excludes` opts out of the defaults and gives you
  full control. `.dart_tool/` is always ignored regardless.
- Immediate compile feedback: the reload line is rendered the moment a file
  change is observed (`CompileStarted`) instead of waiting for the VM to
  finish. The full restart vs. hot reload verb is decided upfront and shown
  as the definitive label, so there's no dim-then-swap flicker.
- "hot restart" label is now shown when the entrypoint file itself is
  modified (previously displayed as "update"), matching the underlying
  behavior of forcing a full process restart.
- `lib/src/version.dart` exposes the package version for CLI surfacing.

### Changed

- JSON event payloads use shorter, less ambiguous `kind` values:
  `hotReload` → `reload`, `hotRestart` → `restart`. The internal
  `ReloadKind` enum is unchanged. Consumers of `--format=json` need to
  update any field they assert on.
- Removed the "compiled in xx ms" suffix from terminal output — the verb +
  trigger line is enough; the timing wasn't actionable.

### Fixes

- Force a full restart when the entrypoint file is modified. A hot reload
  would re-load the source but never re-execute `main()`, leaving the app
  in a stale state.
- Detect post-restart crashes and emit `CompileFailed` so the error is
  rendered in place of a stale "reloading…" header.
- Suppress the reloading header when a reload resolves to an error — only
  the error itself is shown.
- Suppress remaining VM-service info lines that occasionally leaked into
  child stdout/stderr.
- Restart the child process when the VM service connection is disposed
  with an RPC error, instead of hanging on a dead socket.
- Close the `RuntimeBridge` startup race more reliably by polling for the
  `ext.hmr.dispatch` extension during initial child startup.

## 2.0.0

**Flutter-grade HMR for CLI Dart applications.** Major rewrite around the Dart
VM service: true hot reload (no recompilation pipeline, no isolate restart),
preserved app state, and a child-side runtime API for reacting to events.

### Highlights

Three supported usage modes:

1. **Built-in CLI** (`hmr`) — zero-config supervisor for the 80% case.
2. **Runtime API** (`package:hmr/runtime.dart`) — opt into typed hooks
   (`onReload`, `onRestart`, `onFile*`) from inside your app.
3. **Custom runner** (`package:hmr/hmr.dart`) — compose `VmServiceProcessStrategy`,
   `FileWatcher`, filters, presenters and `HotKeyController` to build your own
   supervisor. See `example/bin/custom_hmr.dart`.

### New

- `VmServiceProcessStrategy` — launches the entrypoint as a child process with
  `--enable-vm-service=0`, then issues `reloadSources` on file changes.
- Automatic fallback from hot reload to a full restart on shape changes.
- Full restart automatically triggered when the entrypoint file itself is
  modified (a hot reload would skip `main()` re-execution).
- `package:hmr/runtime.dart` — opt-in `Hmr.instance` API for the child process
  to subscribe to typed events (`onReload`, `onRestart`, `onFileCreated`,
  `onFileModified`, `onFileDeleted`, `onFileMoved`, or a generic `on<E>`).
  Handler exceptions are caught and logged — a buggy hook can never crash the
  supervised app. No-op outside the supervisor, so the same `main()` works for
  both `hmr` and plain `dart run`.
- `RuntimeBridge` forwards events from the parent to the child via the
  `ext.hmr.dispatch` VM service extension, with bounded polling to absorb
  child startup latency without dropping early events.
- Hot keys: `r` (reload), `R` (restart), `c` (clear), `h` (help), `q` (quit).
- Structured event model with JSON serialization (`--format=json`) covering
  `started`, `compileStarted`, `compileSucceeded`, `compileFailed`,
  `reloadSucceeded`, `reloadFailed`, `fileChanged`, `processCrashed`,
  `stopped`. Same shape consumed by the runtime API.
- `ProcessCrashed` preserves the full child stderr verbatim — no truncation.
- `EntrypointResolver` with a documented priority chain: CLI arg → pubspec
  `hmr.entrypoint` → `bin/<package>.dart` → `bin/main.dart`.
- `example/bin/custom_hmr.dart` — runnable template for building your own
  supervisor from the library's building blocks.

### Breaking

- Removed `IsolateRestartStrategy` and the `--strategy` flag — every run uses
  the VM-service strategy.
- Removed the `--rescan-extension` flag (use the runtime API instead).
- Renamed `impl/` to `example/` (pub.dev convention).
- Renamed `VmServiceReloadStrategy` → `VmServiceProcessStrategy`.
- Removed the legacy `Runner` / `Watcher` / `IgnoreMiddleware` /
  `DebounceMiddleware` / `IncludeMiddleware` API; build a custom supervisor
  with `ReloadOrchestrator` + `FileWatcher` + `ignoreSegment`/`includeGlobs`/
  `excludeGlobs` filters instead.

### Fixes

- Surface a clear, red error message when the configured entrypoint does not
  exist, instead of the cryptic `Bad state: VM service URI not found in child
process output`.
- Stop dropping early runtime-API events: `RuntimeBridge.init` now polls the
  isolate (default 500 ms) for `ext.hmr.dispatch` instead of checking once,
  closing the race between parent VM-service handshake and child `main()`.
- Suppress VM-service URI lines from child stdout/stderr so terminal output
  stays focused on app logs.
- Detect post-restart crashes and emit `CompileFailed` so reload errors are
  rendered without a stale "reloading…" header.

### Docs

- Rewritten `README.md` with a table of contents, the three usage modes, a
  full `pubspec.yaml` schema reference, CLI flags, runtime API table, and a
  table of every library symbol exported for custom runners.
- New `example/README.md` covering both the watched-app demo and the
  `custom_hmr.dart` template.

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
