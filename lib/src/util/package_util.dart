import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _logger = Logger('orcm.pubspec');

bool _isPubGetNecessary(String packageRoot) {
  final packageConfig =
      File(p.join(packageRoot, '.dart_tool', 'package_config.json'));
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  final pubspecLock = File(p.join(packageRoot, 'pubspec.lock'));

  if (!pubspec.existsSync()) {
    throw ArgumentError('pubspec.yaml not found in directory: $packageRoot');
  }

  if (packageConfig.existsSync() && pubspecLock.existsSync()) {
    return !pubspecLock.lastModifiedSync().isAfter(pubspec.lastModifiedSync());
  }

  return true;
}

Future<void> runPubGetIfNeeded(String packageRoot) async {
  if (_isPubGetNecessary(packageRoot)) {
    await runPubGet(packageRoot);
  } else {
    _logger.info(
        'Skipping `pub get`, which has already been run, in `$packageRoot`');
  }
}

Future<void> runPubGet(String workingDirectory) async {
  _logger.info('Running `pub get` in `$workingDirectory`...');

  final process = await Process.start('pub', ['get'],
      workingDirectory: workingDirectory,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio);
  final exitCode = await process.exitCode;

  if (exitCode == 69) {
    _logger.info(
        'Re-running `pub get` but with `--offline`, to hopefully fix the above error.');
    final process = await Process.start('pub', ['get', '--offline'],
        workingDirectory: workingDirectory,
        runInShell: true,
        mode: ProcessStartMode.inheritStdio);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('pub get failed with exit code: $exitCode');
    }
  } else if (exitCode != 0) {
    throw Exception('pub get failed with exit code: $exitCode');
  }
}

String findPackageRootFor(String path) {
  final packageRoot = _closestDirectoryContainingFile(path, 'pubspec.yaml');
  if (packageRoot == null) {
    throw Exception('Could not find package root for file `$path`');
  }

  return packageRoot;
}

String? _closestDirectoryContainingFile(String startingPath, String filename) {
  if (p.basename(filename) != filename) {
    throw ArgumentError.value(
        filename, 'filename', 'must be a filename and not a path');
  }

  final directoriesToCheck = [
    startingPath,
    ...ancestorsOfPath(startingPath),
  ];

  return directoriesToCheck
      .firstWhereOrNull((path) => File(p.join(path, filename)).existsSync());
}

/// Returns canonicalized paths for all the the ancestor directories of [path],
/// starting with its parent and working upwards.
Iterable<String> ancestorsOfPath(String path) sync* {
  path = p.canonicalize(path);

  // p.dirname of the root directory is the root directory, so if they're the same, stop.
  final parent = p.dirname(path);
  if (p.equals(path, parent)) return;

  yield parent;
  yield* ancestorsOfPath(parent);
}

bool isNotWithinTopLevelBuildOutputDir(File file) =>
    !isWithinTopLevelDir(file, 'build');

bool isNotWithinTopLevelToolDir(File file) =>
    !isWithinTopLevelDir(file, 'tool');

bool isWithinTopLevelDir(File file, String topLevelDir) =>
    ancestorsOfPath(file.path).any((ancestor) =>
        p.basename(ancestor) == topLevelDir &&
        File(p.join(p.dirname(ancestor), 'pubspec.yaml')).existsSync());
