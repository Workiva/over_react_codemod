import 'dart:io';
import 'package:logging/logging.dart';

import 'package:io/ansi.dart' as ansi;

Logger logger = Logger('orcm.logging');
bool verbose = true;
 void initLogging(verbose, String message) {

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    var colorizer;
    IOSink output;

    if (rec.level >= Level.SEVERE) {
      colorizer = ansi.backgroundRed.wrap;
      output = stderr;
    } else if (rec.level >= Level.WARNING) {
      colorizer = ansi.backgroundLightYellow.wrap;
      output = stderr;
    } else{
      colorizer = _noopColorizer;
      output = stdout;
    }

    if (rec.message != '') {
      output.writeln(colorizer(rec.message));
    }
    if (rec.error != null) {
      output.writeln(colorizer(rec.error.toString()));
    }
    if (verbose && rec.stackTrace != null) {
      output.writeln(colorizer(rec.stackTrace.toString()));
    }

});

}
String _noopColorizer(String string) => string;

// void logInfo(String message){
//   initLogging(verbose,message);
//   logger.info(message);
// }

void logWarning(String message){
  initLogging(verbose,message);
  logger.warning(message);
}
void logShout(String message){
  initLogging(verbose,message);
  logger.shout(message);
}




