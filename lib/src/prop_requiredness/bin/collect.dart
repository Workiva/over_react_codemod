import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/prop_requiredness/analysis.dart';
import 'package:over_react_codemod/src/prop_requiredness/collect.dart';
import 'package:over_react_codemod/src/prop_requiredness/collected_data.sg.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/parse_spec.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/spec.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/version_manager.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import '../logging.dart';

const individualResultsDir = '.package-cache/prop_requiredness/';

Future<void> main(List<String> args) async {
  assert(
      false,
      'The analyzer can throw a "Bad state: Expected all legacy types" error when'
      ' it encounters certain code asserts are enabled.'
      ' Disable asserts to run this script successfully.');

  final argParser = ArgParser()
    ..addFlag('help', help: 'Print this usage information', negatable: false)
    ..addOption('output-directory',
        abbr: 'o',
        help: 'The directory to output individual package results to.',
        defaultsTo: '.');
  final parsedArgs = argParser.parse(args);
  if (parsedArgs['help'] as bool) {
    print('''
Collects prop usage data on the specified package(s). 
This data can then be aggregated into prop requiredness results in aggregate.dart.

Usage: <collect-script> <package_spec> [additional_package_specs...]

${argParser.usage}

$packageSpecFormatsHelpText''');
    exit(ExitCode.success.code);
  }

  final outputDirectory = parsedArgs['output-directory'];
  final packageSpecStrings = parsedArgs.rest;
  if (packageSpecStrings.isEmpty) {
    print('Must specify package(s).\n${argParser.usage}');
    exit(ExitCode.usage.code);
  }

  initLogging();

  late final versionManager = PackageVersionManager.persistentSystemTemp();

  final logger = Logger('prop_requiredness.collect');
  logger.info('Parsing/initializing package specs..');
  final packages = await Future.wait(packageSpecStrings.map((arg) {
    return parsePackageSpec(arg, getVersionManager: () => versionManager);
  }));

  logger.info('Done. Package specs: ${packages.map((p) => '\n- $p').join('')}');

  logger.info('Processing packages and writing to $outputDirectory...');

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
      outputDirectory: outputDirectory,
    ))!;
    allResults.add(result);
    logger.info(result);
    for (final otherPackage in result.otherPackagesProcessed) {
      if (processedPackages.contains(otherPackage)) {
        throw Exception('$otherPackage was double-processed');
      }
      processedPackages.add(otherPackage);
    }
    processedPackages.add(packageName);
  }

  logger.info('All results:\n${allResults.map((r) => '- $r\n').join('')}');
  logger.info(
      'All result files: ${allResults.map((r) => r.outputFilePath).join(' ')}');

  logger.info('Done!');

  logger.info('To aggregate data, run the following command:\n'
      '    dart run bin/prop_requiredness/aggregate.dart ${allResults.map((r) => r.outputFilePath).join(' ')}');
}

class CollectDataForPackageResult {
  final String outputFilePath;
  final Set<String> otherPackagesProcessed;

  CollectDataForPackageResult({
    required this.outputFilePath,
    required this.otherPackagesProcessed,
  });

  @override
  String toString() => 'CollectDataForPackageResult(${{
        'outputFilePath': outputFilePath,
        'otherPackagesProcessed': otherPackagesProcessed.toList(),
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
  outputDirectory ??= '.';

  final rootPackageName = package.packageName;
  final logger = Logger('prop_requiredness.${package.packageAndVersionId}');

  final outputFile = File(p.normalize(
      p.join(outputDirectory, '${package.packageAndVersionId}.json')));

  if (skipIfAlreadyCollected && outputFile.existsSync()) {
    final existingResults = tryParseResults(outputFile.readAsStringSync());
    if (existingResults != null &&
        existingResults.dataVersion == PackageResults.latestDataVersion) {
      logger.info('Skipping since data already exists: ${outputFile.path}');
      return CollectDataForPackageResult(
        outputFilePath: outputFile.path,
        otherPackagesProcessed: existingResults.otherPackageNames,
      );
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

  logger.fine("Collecting data for $rootPackageName...");

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

  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(jsonEncode(results));
  logger.info('Wrote data to ${outputFile.path}');

  return CollectDataForPackageResult(
    outputFilePath: outputFile.path,
    otherPackagesProcessed: results.otherPackageNames,
  );
}

dynamic tryParseJson(String content) {
  try {
    return jsonDecode(content);
  } catch (_) {
    return null;
  }
}