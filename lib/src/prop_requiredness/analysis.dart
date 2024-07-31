import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import 'package/spec.dart';

Future<PackageInfo> getPackageInfo(PackageSpec package) async {
  final directory = await package.getDirectory();
  final pubspecFile = File(p.join(directory.path, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw Exception('Expected to find a pubspec in ${pubspecFile.path}');
  }
  final pubspecContent = await pubspecFile.readAsString();

  final libDirectory = p.canonicalize(p.join(directory.path, 'lib'));
  final canonicalizedPaths =
      allDartFilesWithin(libDirectory).map(p.canonicalize).toList();
  if (canonicalizedPaths.isEmpty) {
    throw Exception(
        "No Dart files found in lib directory '$libDirectory'. Something probably went wrong.");
  }

  return PackageInfo(
    root: directory.path,
    libFiles: canonicalizedPaths,
    pubspecContent: pubspecContent,
    libDirectory: libDirectory,
  );
}

List<String> allDartFilesWithin(String path) {
  return Glob('**.dart', recursive: true)
      .listSync(root: path)
      .whereType<File>()
      .map((file) => file.path)
      .toList();
}

class PackageInfo {
  final String root;
  final String libDirectory;
  final List<String> libFiles;
  final String pubspecContent;

  PackageInfo({
    required this.root,
    required this.libDirectory,
    required this.libFiles,
    required this.pubspecContent,
  });
}

Stream<ResolvedUnitResult> getResolvedLibUnitsForPackage(
  PackageSpec package, {
  required bool includeDependencyPackages,
  bool Function(Package)? packageFilter,
}) async* {
  final logger =
      Logger('getResolvedLibUnitsForPackage.${package.packageAndVersionId}');

  final analyzeStopWatch = Stopwatch()..start();

  final packageRoot = await package.getDirectory();
  final libDirectory = p.canonicalize(p.join(packageRoot.path, 'lib'));
  final collection = AnalysisContextCollection(includedPaths: [libDirectory]);
  final context = collection.contexts.single;

  Iterable<String>? otherPackagesFiles;
  if (includeDependencyPackages) {
    final packagesFile = context.contextRoot.packagesFile;
    if (packagesFile == null) {
      throw Exception(
          'No packages file found for context with root ${context.contextRoot.workspace.root}');
    }
    final resourceProvider = context.contextRoot.resourceProvider;
    final packageConfig =
        await loadPackageConfigUri(packagesFile.toUri(), loader: (uri) async {
      return resourceProvider
          .getFile(resourceProvider.pathContext.fromUri(uri))
          .readAsBytesSync();
    });
    final otherPackageRootPaths = packageConfig.packages
        .where((p) => p.name != package.packageName)
        .where((p) => packageFilter?.call(p) ?? true)
        .map((p) => resourceProvider.pathContext.fromUri(p.packageUriRoot));
    otherPackagesFiles =
        otherPackageRootPaths.map(p.canonicalize).expand(allDartFilesWithin);
  }

  final filesToAnalyze = [
    ...context.contextRoot.analyzedFiles(),
    ...?otherPackagesFiles,
  ];

  logger.finer('Processing units in ${package.packageName} package...');
  for (final path in filesToAnalyze) {
    if (!path.endsWith('.dart')) continue;

    // Don't use collection.contextFor(path) since it fails for files in other packages.
    final result = await context.currentSession.getResolvedUnit(path);
    if (result is ResolvedUnitResult) {
      if (result.exists) {
        yield result;
      } else {
        logger.warning('File does not exist: $path');
      }
    } else {
      logger.warning('Issue resolving $path $result');
    }
  }

  logger.finer(
      'Done. Analysis (and async iteration) took ${analyzeStopWatch.elapsed}');
  analyzeStopWatch.stop();
}
