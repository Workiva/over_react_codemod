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
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_configs_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_importer.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;

import '../util.dart';

final _log = Logger('orcm.intl_message_migration');

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
    ..addMultiOption(
      'migrators',
      defaultsTo: ['prop', 'child', 'displayName'],
      allowed: ['prop', 'child', 'displayName'],
    );

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] as bool) {
    stderr.writeln('Migrates string usage to wrap in Intl.message');
    stderr.writeln();
    stderr.writeln('Usage:');
    stderr.writeln('    intl_migration [arguments]');
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
  // we want that set up before we do other non-codemod things that might log.
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
  print('^ Ignore the "codemod found no files" warning above for now.');

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

  final FileSystem fs = const LocalFileSystem();
  final dartPaths = dartFilesToMigrate().toList();
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

  exitCode = await runInteractiveCodemod(
    [],
    (_) async* {},
    args: codemodArgs,
    additionalHelpOutput: parser.usage,
  );
  if (exitCode != 0) return;
  print('^ Ignore the "codemod found no files" warning above for now.');

  for (String package in packageRoots) {
    _log.info('Starting migration for $package');

    final packageRoot = p.basename(package);
    final packageName = packageNameLookup[packageRoot] ?? 'fix_me_bad_name';
    _log.info('Starting migration for $packageName');
    final packageDartPath;
    try {
      packageDartPath =
          dartFilesToMigrateForPackage(package, processedPackages).toList();
    } on FileSystemException {
      _log.info('${package} does not have a lib directory, moving on...');
      continue;
    }
    sortPartsLast(packageDartPath);

    final File outputFile = fs.currentDirectory.childFile(
        p.join(package, 'lib', 'src', 'intl', '${packageName}_intl.dart'));
    final bool existingOutputFile = outputFile.existsSync();

    final className = toClassName('${packageName}');
    final classPredicate =
        "import 'package:intl/intl.dart';\n\n//ignore: avoid_classes_with_only_static_members\nclass $className {\n";
    if (!existingOutputFile) {
      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(classPredicate);
    } else {
      final List<String> lines = outputFile.readAsLinesSync();
      lines.removeLast();
      String outputContent = lines.join('\n');
      outputFile.writeAsStringSync(outputContent);
    }

    final intlPropMigrator = IntlMigrator(className, outputFile);
    final displayNameMigrator = ConfigsMigrator(className, outputFile);
    final importMigrator =
        (FileContext context) => intlImporter(context, packageName, className);

    exitCode = await runCodemodSequences(packageDartPath, [
      [intlPropMigrator],
      [displayNameMigrator],
      [importMigrator]
    ]);

    processedPackages.add(package);
    if (exitCode != 0 || outputFile.readAsStringSync() == classPredicate) {
      outputFile.deleteSync();
    } else {
      List<String> lines = outputFile.readAsLinesSync();
      final functions = lines.sublist(4);
      functions.removeWhere((string) => string == '');
      functions.sort();
      lines.replaceRange(4, lines.length, functions);
      lines.add('}');
      outputFile.writeAsStringSync(lines.join('\n'), mode: FileMode.write);
    }
  }
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

  dartPaths.sort((a, b) {
    final isAPart = isPart(a);
    final isBPart = isPart(b);

    if (isAPart == isBPart) return 0;
    return isAPart ? 1 : -1;
  });
  _log.info('Done.');
}

void sortDeepestFirst(Set<String> packageRoots) {
  _log.info('Sorting package roots...');

  packageRoots
    ..toList().sort((packageA, packageB) => packageA.length - packageB.length)
    ..toSet();
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
    .where((file) => !file.path.contains('.sg'))
    .where((file) => !file.path.endsWith('_test.dart'))
    .where(isNotHiddenFile)
    .where(isNotDartHiddenFile)
    .where(isNotWithinTopLevelBuildOutputDir)
    .where(isNotWithinTopLevelToolDir)
    .map((e) => e.path);

Iterable<String> dartFilesToMigrateForPackage(
        String package, Set<String> processedPackages) =>
    Glob(p.join(package, 'lib', '*', '**.dart'), recursive: true)
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.contains('.sg.g.dart'))
        .where((file) => !file.path.contains('.sg.freezed.dart'))
        .where((file) => !file.path.endsWith('_test.dart'))
        .where(isNotHiddenFile)
        .where(isNotDartHiddenFile)
        .where(isNotWithinTopLevelBuildOutputDir)
        .where(isNotWithinTopLevelToolDir)
        .where((file) => !processedPackages.contains(file.path))
        .map((e) => e.path)
        .toList();

Iterable<String> experienceConfigDartFiles() => [
      for (var f in Glob('**.dart', recursive: true).listSync())
        if (f is File && f.path.contains('_experience_config.dart')) f.path
    ];
