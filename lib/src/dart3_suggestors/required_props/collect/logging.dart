// Copyright 2024 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
