import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/dart3_suggestors/required_props/collect/aggregate.dart';
import 'package:over_react_codemod/src/dart3_suggestors/required_props/collect/analysis.dart';
import 'package:over_react_codemod/src/dart3_suggestors/required_props/collect/collect.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:over_react_codemod/src/util/command_runner.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import '../collect/collected_data.sg.dart';
import '../collect/logging.dart';
import '../collect/package/parse_spec.dart';
import '../collect/package/spec.dart';
import '../collect/package/version_manager.dart';

const individualResultsDir = '.package-cache/prop_requiredness/';

class CollectCommand extends Command {
  @override
  String get description =>
      'Collects prop usage data on the specified package(s) and aggregates it, writing to $defaultAggregatedOutputFile.';

  @override
  String get name => 'collect';

  @override
  String get invocation =>
      '$invocationPrefix [<options>] <package_spec> [<package_spec>...]';

  @override
  String get usageFooter =>
      '\n$packageSpecFormatsHelpText\n\n$_usageInstructions';

  String get _usageInstructions => r'''
Instructions
============

To collect data, first identify the least-common consumers of your package.

For example, say you're dealing with package A, which is directly consumed by packages B, E, and F, and so on:

    A---B---C---D
    |\     /
    | E----
    \
     F---G---H'''
      '''
\n\nThe least-common consumers would be C (covers both B and E) and F, so we'd run:

   $invocationPrefix pub@…:C pub@…:F

Note: if F were to re-export members of A, which could potentially get used in G, we'd do G instead of F.

   $invocationPrefix pub@…:C pub@…:G
   
Alternatively, you could just run on D and H from the start, but if they include more transitive dependencies,
then the analysis step of the collection process will take a bit longer.
''';

  CollectCommand() {
    argParser
      ..addOption(
        'raw-data-output-directory',
        help: 'An optional directory to output raw usage data file to.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'The file to write aggregated results to.',
        valueHelp: 'path',
        defaultsTo: defaultAggregatedOutputFile,
      )
      ..addFlag(
        'verbose',
        defaultsTo: false,
        negatable: false,
        help: 'Enable verbose output.',
      );
  }

  @override
  FutureOr? run() async {
    final parsedArgs = this.argResults!;

    final aggregatedOutputFile = parsedArgs['output']! as String;
    final verbose = parsedArgs['verbose']! as bool;

    var rawDataOutputDirectory =
        parsedArgs['raw-data-output-directory'] as String?;

    final packageSpecStrings = parsedArgs.rest;
    if (packageSpecStrings.isEmpty) {
      usageException('Must specify package(s).');
    }

    initLogging(verbose: verbose);

    late final versionManager = PackageVersionManager.persistentSystemTemp();

    final logger = Logger('prop_requiredness.collect');
    logger.info('Parsing/initializing package specs...');
    final packages = await Future.wait(packageSpecStrings.map((arg) {
      return parsePackageSpec(arg, getVersionManager: () => versionManager);
    }));

    logger
        .info('Done. Package specs: ${packages.map((p) => '\n- $p').join('')}');

    logger.info('Processing packages...');
    if (rawDataOutputDirectory != null) {
      logger.info(
          "Writing raw usage data to directory '$rawDataOutputDirectory'...");
    }

    final allResults = <CollectDataForPackageResult>[];

    final processedPackages = <String>{};
    for (final packageSpec in packages) {
      final packageName = packageSpec.packageName;
      if (processedPackages.contains(packageName)) {
        throw Exception('Already processed $packageName');
      }

      final result = (await collectDataForPackage(
        packageSpec,
        processDependencyPackages: true,
        skipIfAlreadyCollected: false,
        skipIfNoUsages: false,
        packageFilter: (p) => !processedPackages.contains(p.name),
        outputDirectory: rawDataOutputDirectory,
      ))!;
      allResults.add(result);
      logger.fine(result);
      for (final otherPackage in result.results.otherPackageNames) {
        if (processedPackages.contains(otherPackage)) {
          throw Exception('$otherPackage was double-processed');
        }
        processedPackages.add(otherPackage);
      }
      processedPackages.add(packageName);
    }
    logger.info('Done!');
    logger.fine('All results:\n${allResults.map((r) => '- $r\n').join('')}');
    logger.info(
        'All result files: ${allResults.map((r) => r.outputFilePath).join(' ')}');

    logger.info('Aggregating raw usage data...');

    final aggregated = aggregateData(allResults.map((r) => r.results).toList());

    File(aggregatedOutputFile)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncodeIndented(aggregated));
    logger.info(
        'Wrote aggregated prop requiredness data to ${aggregatedOutputFile}');
  }
}

final jsonEncodeIndented = const JsonEncoder.withIndent('  ').convert;

class CollectDataForPackageResult {
  final PackageResults results;
  final String? outputFilePath;

  CollectDataForPackageResult({
    required this.results,
    required this.outputFilePath,
  });

  @override
  String toString() => 'CollectDataForPackageResult(${{
        'outputFilePath': outputFilePath,
        'results.otherPackageNames': results.otherPackageNames.toList(),
      }})';
}

Future<CollectDataForPackageResult?> collectDataForPackage(
  PackageSpec package, {
  bool processDependencyPackages = false,
  bool Function(Package)? packageFilter,
  bool skipIfAlreadyCollected = true,
  bool skipIfNoUsages = true,
  String? outputDirectory,
}) async {
  final rootPackageName = package.packageName;
  final logger = Logger('prop_requiredness.${package.packageAndVersionId}');

  logger.info("Collecting raw usage data for $rootPackageName...");

  File? outputFile;
  if (outputDirectory != null) {
    outputFile = File(p.normalize(
        p.join(outputDirectory, '${package.packageAndVersionId}.json')));

    if (skipIfAlreadyCollected && outputFile.existsSync()) {
      final existingResults = tryParseResults(outputFile.readAsStringSync());
      if (existingResults != null &&
          existingResults.dataVersion == PackageResults.latestDataVersion) {
        logger.info('Skipping since data already exists: ${outputFile.path}');
        return CollectDataForPackageResult(
          results: existingResults,
          outputFilePath: outputFile.path,
        );
      }
    }
  }

  final packageInfo = await getPackageInfo(package);
  // Heuristic to help filter out packages that don't contain over_react component usages,
  // so we don't have to spend time resolving them.
  if (skipIfNoUsages &&
      !packageInfo.libFiles
          .any((l) => File(l).readAsStringSync().contains(')('))) {
    logger.fine(
        "Skipping package $rootPackageName since it doesn't look like it contains over_react usages");
    return null;
  }

  // Get latest dependencies, to get latest versions of other packages.
  await runCommandAndThrowIfFailed('dart', ['pub', 'upgrade'],
      workingDirectory: packageInfo.root);

  final units = getResolvedLibUnitsForPackage(package,
      includeDependencyPackages: processDependencyPackages,
      packageFilter: packageFilter);

  final results = await collectDataForUnits(
    units,
    rootPackageName: rootPackageName,
    allowOtherPackageUnits: processDependencyPackages,
  );
  results.packageVersionDescriptionsByName[rootPackageName] =
      package.sourceDescription;

  if (outputFile != null) {
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(jsonEncode(results));
    logger.fine('Wrote data to ${outputFile.path}');
  }

  return CollectDataForPackageResult(
    results: results,
    outputFilePath: outputFile?.path,
  );
}

dynamic tryParseJson(String content) {
  try {
    return jsonDecode(content);
  } catch (_) {
    return null;
  }
}
