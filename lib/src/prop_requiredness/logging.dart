import 'dart:io';

import 'package:logging/logging.dart';

/// Flag to help keep logs and progress output on separate lines.
var lastLogWasProgress = false;

void logProgress([String character = '.']) {
  lastLogWasProgress = true;
  stderr.write(character);
}

void initLogging() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    if (lastLogWasProgress) stderr.writeln();
    lastLogWasProgress = false;

    print(record);
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });
}
