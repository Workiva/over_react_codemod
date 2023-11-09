// Copyright 2023 Workiva Inc.
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
import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:path/path.dart' as p;

final _log = Logger('orcm.intl_message_migration');
final FileSystem fs = const LocalFileSystem();
final parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Prints this help output.',
  );
late ArgResults parsedArgs;

void main(List<String> args) async {
  parsedArgs = parser.parse(args);
  if (parsedArgs['help'] as bool) {
    printUsage();
    return;
  }

  final rootDirectory = p.canonicalize(p.absolute(''));

  // Derive the package name from pubspec.yaml or intl.dart file name
  final packageName = derivePackageName(rootDirectory);

  if (packageName == null) {
    stderr.writeln('Could not determine the package name.');
    return;
  }

  _log.info('Sorting INTL messages for $packageName.');
  final IntlMessages messages = IntlMessages(packageName);
  messages.write();
}

// Derive the package name from pubspec.yaml or intl.dart file name
String? derivePackageName(String rootDirectory) {
  final pubspecPath = p.join(rootDirectory, 'pubspec.yaml');
  if (fs.isFileSync(pubspecPath)) {
    final pubspecContents = fs.file(pubspecPath).readAsStringSync();
    final nameMatch = RegExp(r'name:\s+(\w+)').firstMatch(pubspecContents);
    if (nameMatch != null) {
      return nameMatch.group(1);
    }
  }

  final intlDartFile = p.join(rootDirectory, 'intl.dart');
  if (fs.isFileSync(intlDartFile)) {
    return p.basenameWithoutExtension(intlDartFile);
  }

  return null;
}

void printUsage() {
  stderr.writeln('Sort the INTL file for the package in the current directory');
  stderr.writeln();
  stderr.writeln('Usage:');
  stderr.writeln('sort_intl [arguments]');
  stderr.writeln();
  stderr.writeln('Options:');
  stderr.writeln(parser.usage);
}
