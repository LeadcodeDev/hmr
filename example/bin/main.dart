import 'dart:async';

import 'package:example/counter.dart';
import 'package:example/formatter.dart';

void main(List<String> args) {
  final counter = Counter();
  print('Hello World !');

  Timer.periodic(const Duration(milliseconds: 500), (_) {
    print(format(counter.value));
    counter.increment();
  });
}
