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
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import '../util.dart';
import 'intl_message_migration.dart';

final _log = Logger('orcm.intl_message_migration');

const _noMigrate = 'no-migrate';

final FileSystem fs = const LocalFileSystem();

final parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Prints this help output.',
  )
  ..addFlag(_noMigrate,
      negatable: false,
      defaultsTo: false,
      help:
      'Does not run any migrators, overriding any --migrate flags. Can still be used with --prune-unused, and '
          'will force the messages file to be sorted and rewritten'
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
  packageRoots.sort((packageA, packageB) =>
  p.split(packageB).length - p.split(packageA).length);

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
  await pubGetForAllPackageRoots(dartPaths);

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
    sortPartsLast(packageDartPaths);

    final IntlMessages messages = IntlMessages(packageName);
    messages.write();


  }
}

void printUsage() {
  stderr.writeln(
      'Migrates literal strings that seem user-visible in the package by wrapping them in Intl.message calls.');
  stderr.writeln();
  stderr.writeln('Usage:');
  stderr.writeln('intl_sorting [arguments]');
  stderr.writeln();
  stderr.writeln('Options:');
  stderr.writeln(parser.usage);
}


Future<int> runMigrators(

List<String> packageDartPaths, IntlMessages messages, String packageName)
async {

  final intlPropMigrator = IntlMigrator(messages.className, messages);
  List<List<Migrator>> migrators = [
    if (parsedArgs[_noMigrate]) [intlPropMigrator],
  ];

  List<List<Migrator>> thingsToRun = [
    if (!parsedArgs[_noMigrate]) ...migrators,

  ];
  List<String> codemodArgs= [_noMigrate];
  var result =
  await runCodemodSequences(packageDartPaths, thingsToRun, codemodArgs);
  return result;
}

void sortPartsLast(List<String> dartPaths) {
  _log.info('Sorting part files...');

  final isPartCache = <String, bool>{};
  bool isPart(String path) => isPartCache.putIfAbsent(path, () {
    // parseString is much faster than using an AnalysisContextCollection
    //  to get unresolved AST, at least in repos with many context roots.
    final unit = parseString(
        content: LocalFileSystem().file(path).readAsStringSync())
        .unit;
    return unit.directives.whereType<PartOfDirective>().isNotEmpty;
  });

  if (dartPaths.isNotEmpty && dartPaths.every(isPart)) {
    _log.info(
        'Only part files were specified. The containing library must be included for any part file, as it is needed for analysis context');
    exit(1);
  }
  dartPaths.sort((a, b) {
    final isAPart = isPart(a);
    final isBPart = isPart(b);

    if (isAPart == isBPart) return 0;
    return isAPart ? 1 : -1;

  });
  _log.info('Done.');

}




