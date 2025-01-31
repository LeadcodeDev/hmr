# 🚀 Hot Module Replacement for Dart Applications

**HMR Dart** is a Hot Module Replacement system specially designed for command-line Dart applications.

It allows you to :
- Hot reload code without restarting the application
- Maintain application status during updates
- Monitor files in real time
- Intelligently manage recompilations

## 🛠 Key features

| Feature                  | Description                                        |
|--------------------------|----------------------------------------------------|
| 🪄 Ready to use          | No configuration required                          |
| ⚡ Instant reloading      | Instant code update                                |
| 🎯 Targeted surveillance | Filtering by glob patterns (`includes`/`excludes`) |
| 🔍 Visual feedback       | ANSI colours + change counter                      |
| 🔄 Error management      | Compiler error messages with highlight             |
| 📝 Extendable            | Build your own HMR system using event handling     |
| 📦 Extremely small size  | Package size `< 10ko`                                |


## Global usage

### Installation
Install the package globally in your environment.
```bash
dart pub global activate hmr
```

### Configuration

In your `pubspec.yaml`, you can add an additional configuration to the `hmr`.
```yaml
hmr:
  # Change the location of the input file
  entrypoint: bin/main.dart

  # Only include files that meet the following criteria
  includes:
    - '**/*.txt'
    - '**/*.dart'
      
  # Exclude files meeting the following criteria
  excludes:
    - '.dart_tool/**'
```

The inclusion and exclusion of files is optional.
If you don't specify any criteria, all files matching the `Glob(‘**.dart’)` criterion will be monitored.

### Usage

```bash
$ cd /path/to/your/project
$ hmr
```

> The [Glob](https://pub.dev/packages/glob) library is used to manage the inclusion and exclusion of monitored files.

## 📦 Manual installation

Add to your `pubspec.yaml` :
```yaml
dependencies:
  hmr: ^1.0.0
```

## 🚀 Usage

Create a `bin/hmr.dart` file.
```dart
import 'package:hmr/hmr.dart';

void main() {  
  final runner = Runner(
    tempDirectory: Directory.systemTemp,
    entrypoint: File(
      path.join([
        Directory.current.path,
        'bin',
        'main.dart'
      ])
    ));

  final watcher = Watcher(
    includes: [Glob("**.dart")],
    onStart: () => print('Watching for changes...'),
    onFileChange: (int eventType, File file) async {
      final action = switch (eventType) {
        FileSystemEvent.create => 'created',
        FileSystemEvent.modify => 'modified',
        FileSystemEvent.delete => 'deleted',
        FileSystemEvent.move => 'moved',
        _ => 'changed'
      };
      
      print('File $action ${file.path}');
      await runner.reload();
    });

  watcher.watch();
  runner.run();
}
```

Start HMR mode:
```bash
$ dart run bin/hmr.dart
```
