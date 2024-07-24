import 'dart:io';

import 'package:over_react_codemod/src/prop_requiredness/package/metadata.dart';
import 'package:path/path.dart' as p;

import 'spec.dart';
import 'version_manager.dart';

PackageSpec packageSpecFromPackageVersion(
    PackageVersion version, PackageVersionManager versionManager) {
  return PackageSpec(
    packageName: version.packageName,
    versionId: version.version,
    sourceDescription: version.toString(),
    getDirectory: () => versionManager.getExtractedFolder(version),
  );
}

Future<void> _resetPubspecLock(Directory directory) async {
  // pubspec.lock shouldn't be included in published packages, so always delete it.
  final pubspecLockFile = File(p.join(directory.path, 'pubspec.lock'));
  if (pubspecLockFile.existsSync()) pubspecLockFile.deleteSync();
}

Future<PackageSpec> pubPackageSpec({
  required String packageName,
  String? version,
  required PackageVersionManager versionManager,
  required String host,
}) async {
  version ??= await getLatestVersionOfPackage(packageName, host: host);
  final packageVersion = PackageVersion(
    hostUrl: host,
    packageName: packageName,
    version: version,
  );
  return packageSpecFromPackageVersion(packageVersion, versionManager);
}
