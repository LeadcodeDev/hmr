// Simulates a shape change in Counter by adding a new field.
//
// Run with: dart tool/shape_change.dart
//
// When hmr is watching, this should trigger the shape-change fallback
// (a full process restart) because adding a field changes the class layout.
//
// To revert: dart tool/shape_change.dart --revert
import 'dart:io';

const _path = 'lib/counter.dart';

const _original = '''class Counter {
  int value = 0;

  void increment() => value++;
  void reset() => value = 0;
}
''';

const _modified = '''class Counter {
  int value = 0;
  int ticks = 0; // shape change: new field

  void increment() {
    value++;
    ticks++;
  }

  void reset() {
    value = 0;
    ticks = 0;
  }

  @override
  String toString() => 'Counter(value: \$value, ticks: \$ticks)';
}
''';

void main(List<String> args) {
  final revert = args.contains('--revert');
  final file = File(_path);
  if (!file.existsSync()) {
    stderr.writeln('Run this script from the example/ directory.');
    exit(1);
  }

  if (revert) {
    file.writeAsStringSync(_original);
    print('Reverted $_path to original.');
  } else {
    file.writeAsStringSync(_modified);
    print('Applied shape change to $_path (added ticks field).');
    print('If hmr is running, watch for a hotRestart event.');
  }
}
