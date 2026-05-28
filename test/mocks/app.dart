import 'dart:io';
import 'dart:isolate';

void main(List<String> args, SendPort port) {
  port.send(port);
  exit(0);
}
