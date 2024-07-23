import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/prop_requiredness/analysis.dart';
import 'package:over_react_codemod/src/prop_requiredness/collect.dart';
import 'package:over_react_codemod/src/prop_requiredness/collected_data.sg.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/git.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/local.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/spec.dart';
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

  // Without this logger setup, logs won't be printed to the console
  initLogging();

  final argParser = ArgParser();

  final parsedArgs = argParser.parse(args);

  final packages = await Future.wait(parsedArgs.rest.map(parsePackageSpec));
  await collectDataForPackages(packages);
}

Future<PackageSpec> parsePackageSpec(String packageSpecString) async {
  Never invalidPackageSpec([String additionalMessage = '']) =>
      throw ArgumentError.value(packageSpecString,
          'Could not parse package spec; expected Git URL or a local path$additionalMessage');

  final uri = Uri.tryParse(packageSpecString);
  if ((uri != null && uri.isScheme('https://')) ||
      packageSpecString.startsWith('git@')) {
    final parts = packageSpecString.split('#');
    final repoUrl = parts[0];
    var ref = parts.skip(1).firstOrNull ?? '';
    if (ref.isEmpty) ref = 'HEAD';
    return gitRefPackageSpec(repoUrl, ref);
  }

  if (uri != null && (!uri.hasScheme || uri.isScheme('file'))) {
    final path = uri.toFilePath();
    if (!Directory(path).existsSync()) {
      invalidPackageSpec(' (path does not exist)');
    }
    return localPathPackageSpec(path);
  }

  invalidPackageSpec();
}

Future<void> collectDataForPackages(List<PackageSpec> packages) async {
  final logger = Logger('prop_requiredness');

  logger.info('Processing packages and writing to $individualResultsDir...');

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
}) async {
  final rootPackageName = package.packageName;
  final logger =
      Logger('prop_requiredness.$rootPackageName.${package.versionId}');

  final outputFile = File(p.join(
      individualResultsDir, rootPackageName, '${package.versionId}.json'));

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
