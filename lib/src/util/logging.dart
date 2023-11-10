import 'dart:io';
import 'package:logging/logging.dart';

import 'package:io/ansi.dart' as ansi;

Logger logger = Logger('orcm.logging');

void initLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.clearListeners();
  Logger.root.onRecord.listen((rec) {
    var colorizer;
    IOSink output;
    ansi.AnsiCode color;
    if (rec.level < Level.WARNING) {
      color = ansi.cyan;
      output = stderr;
    } else if (rec.level < Level.SEVERE) {
      color = ansi.yellow;
      output = stderr;
    } else {
      color = ansi.red;
      output = stdout;
    }

    if (rec.message != '') {
      final level = color.wrap('[${rec.level}]');
      output.writeln('$level ${rec.loggerName} ${rec.message}');
    }
    if (rec.error != null) {
      output.writeln(colorizer(rec.error.toString()));
    }
    if (rec.stackTrace != null) {
      output.writeln(colorizer(rec.stackTrace.toString()));
    }
  });
}

String _noopColorizer(String string) => string;

void logWarning(String message) {
  logger.warning(message);
}

void logShout(String message) {
  logger.shout(message);
}
