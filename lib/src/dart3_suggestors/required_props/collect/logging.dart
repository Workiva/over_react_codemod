import 'dart:io';

import 'package:io/ansi.dart';
import 'package:logging/logging.dart';

/// Flag to help keep logs and progress output on separate lines.
var lastLogWasProgress = false;

void logProgress([String character = '.']) {
  lastLogWasProgress = true;
  stderr.write(character);
}

void initLogging({bool verbose = false}) {
  Logger.root.level = verbose ? Level.FINEST : Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (lastLogWasProgress) stderr.writeln();
    lastLogWasProgress = false;

    AnsiCode color;
    if (record.level < Level.WARNING) {
      color = cyan;
    } else if (record.level < Level.SEVERE) {
      color = yellow;
    } else {
      color = red;
    }
    final message = StringBuffer()..write(color.wrap('[${record.level}] '));
    if (verbose) message.write('${record.loggerName}: ');
    message.write(record.message);
    print(message.toString());

    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });
}
