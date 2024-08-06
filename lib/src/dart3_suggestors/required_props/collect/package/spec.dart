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

/// A generic representation of a specific version of a package
/// that can also be used in various analysis tasks.
///
/// Allows decoupling between the way a package is sourced and how it is analyzed.
///
/// For example, this could be  a hosted package from `VersionManager` (see `packageSpecFromPackageVersion`)
/// or any other package source (e.g., a cloned Git revision, a local working copy).
class PackageSpec {
  /// The name of the package.
  ///
  /// This must match the package name in this package's pubspec.yaml.
  final String packageName;

  /// A unique ID that can differentiate this package from others with the same [packageName].
  ///
  /// Must contain only characters that can be used in a valid filename.
  final String versionId;

  /// A human-readable description of the source of this package and version.
  final String sourceDescription;

  /// Returns a future with a directory that has been populated with this package's contents.
  ///
  /// This directory should only be read from.
  ///
  /// For example, this function may download and extract a tarball of a hosted package, or check
  /// out a revision in a Git clone.
  final Future<Directory> Function() getDirectory;

  /// A unique identifier containing [packageName] and [versionId].
  String get packageAndVersionId => '$packageName.$versionId';

  PackageSpec({
    required this.packageName,
    required this.versionId,
    required this.sourceDescription,
    required this.getDirectory,
  });

  @override
  String toString() =>
      'PackageSpec($packageName, $versionId) - $sourceDescription';
}
