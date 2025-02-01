import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  final pubSpecFile = File('pubspec.yaml');

  if (!pubSpecFile.existsSync()) {
    final List<Sequence> sequences = [
      SetStyles(Style.foreground(Color.brightRed)),
      Print('[hmr]'),
      Print(' pubspec.yaml not found, please use this command in a Dart project.'),
      SetStyles.reset,
      AsciiControl.lineFeed
    ];

    stdout.writeAnsiAll(sequences);
    exit(1);
  }

  final pubSpecContent = await pubSpecFile.readAsYaml();
  final tempPath = await Directory.systemTemp.createTemp('hmr');

  final config = pubSpecContent['hmr'] != null ? Config.of(pubSpecContent['hmr']) : null;

  final baseEntrypoint = [Directory.current.path];
  if (config?.entrypoint case final String value) {
    baseEntrypoint.add(value);
  } else {
    baseEntrypoint.addAll(['bin', pubSpecContent['name']]);
  }

  final runner = Runner(
    entrypoint: File(path.joinAll(baseEntrypoint)),
    tempDirectory: tempPath,
  );

  (File, int)? lastFileChanged;

  final watcher = Watcher(
      includes: config?.includes ?? [Glob("**.dart")],
      excludes: config?.excludes ?? [],
      onStart: () {
        final List<Sequence> sequences = [
          const CursorPosition.moveTo(0, 0),
          Clear.afterCursor,
          Clear.allAndScrollback,
          SetStyles(Style.foreground(Color.green)),
          Print('[hmr]'),
          Print(' wait to watch changes...'),
          SetStyles.reset,
          AsciiControl.lineFeed
        ];

        stdout.writeAnsiAll(sequences);
      },
      onFileChange: (int eventType, File file) async {
        lastFileChanged =
            (file, file.path != lastFileChanged?.$1.path ? 0 : lastFileChanged!.$2 + 1);

        final action = switch (eventType) {
          FileSystemEvent.create => 'created',
          FileSystemEvent.modify => 'modified',
          FileSystemEvent.delete => 'deleted',
          FileSystemEvent.move => 'moved',
          _ => 'changed'
        };

        final List<Sequence> sequences = [
          const CursorPosition.moveTo(0, 0),
          Clear.afterCursor,
          Clear.allAndScrollback,
          SetStyles(Style.foreground(Color.green)),
          Print('[hmr] $action '),
          SetStyles(Style.foreground(Color.brightBlack)),
          Print(file.path.replaceFirst('${Directory.current.path}/', '')),
          SetStyles.reset
        ];

        if (lastFileChanged?.$2 != 0) {
          sequences.addAll([
            SetStyles(Style.foreground(Color.yellow)),
            Print(' (x${lastFileChanged!.$2})'),
            SetStyles.reset,
          ]);
        }

        sequences.add(AsciiControl.lineFeed);

        stdout.writeAnsiAll(sequences);
        await runner.reload();
      });

  watcher.watch();
  runner.run();

  void cleanup() {
    runner.dispose();
    watcher.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => cleanup());
  ProcessSignal.sigterm.watch().listen((_) => cleanup());
}
