# Changelog

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
