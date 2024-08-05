// Copyright 2024 Workiva Inc.
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

import 'package:path/path.dart' as p;

import 'metadata.dart';
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
