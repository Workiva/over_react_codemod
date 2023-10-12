// Copyright 2021 Workiva Inc.
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
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/mui_suggestors/components.dart';
import 'package:over_react_codemod/src/mui_suggestors/unused_wsd_import_remover.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';
import 'package:over_react_codemod/src/util/logging.dart';

import '../mui_suggestors/constants.dart';
import '../util/importer.dart';

final _log = Logger('orcm.mui_migration');

const _componentOption = 'component';
const _rmuiVersionOption = 'rmui-version';

const _verboseFlag = 'verbose';
const _yesToAllFlag = 'yes-to-all';
const _failOnChangesFlag = 'fail-on-changes';
const _stderrAssumeTtyFlag = 'stderr-assume-tty';
const _allCodemodFlags = {
  _verboseFlag,
  _yesToAllFlag,
  _failOnChangesFlag,
  _stderrAssumeTtyFlag,
};

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Prints this help output.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Outputs all logging to stdout/stderr.',
    )
    ..addFlag(
      _yesToAllFlag,
      negatable: false,
      help: 'Forces all patches accepted without prompting the user. '
          'Useful for scripts.',
    )
    ..addFlag(
      _failOnChangesFlag,
      negatable: false,
      help: 'Returns a non-zero exit code if there are changes to be made. '
          'Will not make any changes (i.e. this is a dry-run).',
    )
    ..addFlag(
      _stderrAssumeTtyFlag,
      negatable: false,
      help: 'Forces ansi color highlighting of stderr. Useful for debugging.',
    )
    ..addSeparator('MUI Migration Options:')
    ..addOption(
      _rmuiVersionOption,
      defaultsTo: '1.1.1',
      help: 'The react_material_ui version to use when adding it as'
          ' a dependency via a "^" version constraint.',
    )
    ..addMultiOption(
      _componentOption,
      allowed: componentMigratorsByName.keys,
      help: 'Choose which component migrators should be run. '
          'If no components are specified, all component migrators will be run.',
    );

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] as bool) {
    stderr.writeln(
        'Migrates web_skin_dart component usages to react_material_ui.');
    stderr.writeln();
    stderr.writeln('Usage:');
    stderr.writeln('    mui_migration [arguments]');
    stderr.writeln();
    stderr.writeln('Options:');
    stderr.writeln(parser.usage);
    return;
  }

  // It's easier to only pass through codemod flags than it is to try to strip
  // out our custom flags/options (since they can take several forms due to
  // abbreviations and the different syntaxes for providing an option value,
  // especially the two-arg `--option value` syntax).
  //
  // An alternative would be to use `--` and `arguments.rest` to pass along codemod
  // args, but that's not as convenient to the user and makes showing help a bit more complicated.
  final codemodArgs = _allCodemodFlags
      .where((name) => parsedArgs[name] as bool)
      .map((name) => '--$name')
      .toList();

  // codemod sets up a global logging handler that forwards to the console, and
  // we want that set up before we do other non-codemodd things that might log.
  //
  // We could set up logging too, but we can't disable codemod's log handler,
  // so we'd have to disable our own logging before calling into codemod.
  // While hackier, this is easier.
  // TODO each time we call runInteractiveCodemod, all subsequent logs are forwarded to the console an extra time. Update codemod package to prevent this (maybe a flag to disable automatic global logging?)
  exitCode = await runInteractiveCodemod(
    [],
    (_) async* {},
    args: codemodArgs,
    additionalHelpOutput: parser.usage,
  );
  if (exitCode != 0) return;
  logWarning('^ Ignore the "codemod found no files" warning above for now.');

  /// Runs a set of codemod sequences separately to work around an issue where
  /// updates from an earlier suggestor aren't reflected in the resolved AST
  /// for later suggestors.
  ///
  /// This means we have to set up analysis contexts multiple times, which takes longer,
  /// but isn't a dealbreaker. E.g., for wdesk_sdk, running two sequences takes 2:52
  /// as opposed to 2:00 for one sequence.
  ///
  /// If any sequence fails, returns that exit code and short-circuits the other
  /// sequences.
  Future<int> runCodemodSequences(
    Iterable<String> paths,
    Iterable<Iterable<Suggestor>> sequences,
  ) async {
    for (final sequence in sequences) {
      final exitCode = await runInteractiveCodemodSequence(
        paths,
        sequence,
        defaultYes: true,
        args: codemodArgs,
        additionalHelpOutput: parser.usage,
      );
      if (exitCode != 0) return exitCode;
    }

    return 0;
  }

  // Only run the migrators for components that were specified in [args].
  // If no components were specified, run all migrators.
  final componentsToMigrate = parsedArgs[_componentOption] as List<String>;
  final migratorsToRun = componentsToMigrate.isEmpty
      ? componentMigratorsByName.values
      : componentsToMigrate.map((componentName) {
          final migrator = componentMigratorsByName[componentName];
          if (migrator == null) {
            throw Exception('Could not find a migrator for $componentName');
          }
          return migrator;
        }).toList();

  final dartPaths = dartFilesToMigrate().toList();
  // Work around parts being unresolved if you resolve them before their libraries.
  // TODO - reference analyzer issue for this once it's created
  sortPartsLast(dartPaths);

  await pubGetForAllPackageRoots(dartPaths);
  exitCode = await runCodemodSequences(dartPaths, [
    // Aggregate these so we don't have to spin up a new analysis context
    // for each codemod.
    //
    // It should generally be safe to aggregate these since each component usage
    // should only be handled by a single migrator, and shouldn't depend on the
    // output of previous migrators.
    [aggregate(migratorsToRun)],
    [importerSuggestorBuilder(importUri: rmuiImportUri, importNamespace: muiNs)],
    [unusedWsdImportRemover],
  ]);
  if (exitCode != 0) return;

  final rmuiVersion = parsedArgs[_rmuiVersionOption] as String;
  final rmuiVersionRange = parseVersionRange('^$rmuiVersion');
  exitCode = await runInteractiveCodemod(
    pubspecYamlPaths(),
    aggregate([
      PubspecUpgrader('react_material_ui', rmuiVersionRange,
          hostedUrl: 'https://pub.workiva.org'),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: codemodArgs,
    additionalHelpOutput: parser.usage,
  );
  if (exitCode != 0) return;
}

void sortPartsLast(List<String> dartPaths) {
  _log.info('Sorting part files...');

  final isPartCache = <String, bool>{};
  bool isPart(String path) => isPartCache.putIfAbsent(path, () {
        // parseString is much faster than using an AnalysisContextCollection
        //  to get unresolved AST, at least in repos with many context roots.
        final unit = parseString(content: File(path).readAsStringSync()).unit;
        return unit.directives.whereType<PartOfDirective>().isNotEmpty;
      });

  dartPaths.sort((a, b) {
    final isAPart = isPart(a);
    final isBPart = isPart(b);

    if (isAPart == isBPart) return 0;
    return isAPart ? 1 : -1;
  });
  _log.info('Done.');
}

Future<void> pubGetForAllPackageRoots(Iterable<String> files) async {
  _log.info(
      'Running `pub get` if needed so that all Dart files can be resolved...');
  final packageRoots = files.map(findPackageRootFor).toSet();
  for (final packageRoot in packageRoots) {
    await runPubGetIfNeeded(packageRoot);
  }
}

// TODO we'll probably going to need to also ignore files excluded in analysis_options.yaml
// so that our component migrator codemods don't fail when they can't resolve the files.
Iterable<String> dartFilesToMigrate() => Glob('**.dart', recursive: true)
    .listSync()
    .whereType<File>()
    .where(isNotHiddenFile)
    .where(isNotDartHiddenFile)
    .where(isNotWithinTopLevelBuildOutputDir)
    .where(isNotWithinTopLevelToolDir)
    .map((e) => e.path);
