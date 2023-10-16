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

import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import '../util.dart';
import 'intl_message_migration.dart';

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

  // If we have specified paths on the command line, limit our processing to
  // those, and make sure they're absolute.
  var basicDartPaths = parsedArgs.rest.isEmpty ? ['lib'] : parsedArgs.rest;
  var dartPaths = [
    for (var path in basicDartPaths) p.canonicalize(p.absolute(path))
  ];

  // Work around parts being unresolved if you resolve them before their libraries.
  // TODO - reference analyzer issue for this once it's created
  final packageRoots = dartPaths.map(findPackageRootFor).toSet().toList();

  // TODO: Use packageConfig and utilities for reading that rather than manually parsing pubspec..
  Map<String, String> packageNameLookup = {
    for (String path in pubspecYamlPaths())
      p.basename(findPackageRootFor(path)): fs
          .file(path)
          .readAsLinesSync()
          .firstWhere((line) => line.startsWith('name'))
          .split(':')
          .last
          .trim()
  };

  final processedPackages = Set<String>();

  for (String package in packageRoots) {
    final packageRoot = p.basename(package);
    final packageName = packageNameLookup[packageRoot] ?? 'fix_me_bad_name';
    _log.info('Starting migration for $packageName');
    List<String> packageDartPaths;
    try {
      packageDartPaths =
          dartFilesToMigrateForPackage(package, processedPackages).toList();
    } on FileSystemException {
      _log.info('${package} does not have a lib directory, moving on...');
      return;
    }

    packageDartPaths = limitPaths(packageDartPaths, allowed: dartPaths);

    final IntlMessages messages = IntlMessages(packageName);
    messages.write();
  }
}

void printUsage() {
  stderr.writeln('Activating Excutables and Sort INTL file.');
  stderr.writeln();
  stderr.writeln('Usage:');
  stderr.writeln('sort_intl [arguments]');
  stderr.writeln();
  stderr.writeln('Options:');
  stderr.writeln(parser.usage);
}
