import 'dart:io';

import 'package:glob/glob.dart';
import 'package:hmr/hmr.dart';
import 'package:mansion/mansion.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  final pubSpecContent = await File('pubspec.yaml').readAsYaml();
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
        final List<Sequence> sequences = []
          ..add(const CursorPosition.moveTo(0, 0))
          ..add(Clear.allAndScrollback)
          ..addAll([
            SetStyles(Style.foreground(Color.green)),
            Print('[hmr]'),
          ])
          ..add(Print(' wait to watch changes...'))
          ..add(SetStyles.reset)
          ..add(AsciiControl.lineFeed);

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

        final List<Sequence> sequences = []
          ..add(const CursorPosition.moveTo(0, 0))
          ..add(Clear.allAndScrollback)
          ..add(SetStyles(Style.foreground(Color.green)))
          ..add(Print('[hmr] $action '))
          ..add(SetStyles(Style.foreground(Color.brightBlack)))
          ..add(Print(file.path.replaceFirst('${Directory.current.path}/', '')))
          ..add(SetStyles.reset);

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
}
