# Changelog

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
