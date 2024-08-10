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

import 'dart:async';
import 'dart:io' hide HttpClient;

import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:path/path.dart' as p;

import 'temp.dart';

// -------------------------------------------------------------------------------
//
// Packages downloading and extracting
//
// -------------------------------------------------------------------------------

class PackageVersionManager {
  static final logger = Logger('PackageVersionManager');

  final String _cachePath;

  PackageVersionManager(this._cachePath);

  factory PackageVersionManager.persistentSystemTemp() {
    final directory =
        Directory(p.join(packageTempDirectory().path, 'version_manager'))
          ..createSync(recursive: true);
    return PackageVersionManager(directory.path);
  }

  String get _downloadsFolder => p.join(_cachePath, 'downloads');

  String get _extractedFolder => p.join(_cachePath, 'extracted');

  String _hostAsDirectoryName(String url) =>
      Uri.parse(url).authority.replaceAll(RegExp(r'[^\w.]'), '');

  String packageVersionName(PackageVersion version) =>
      '${version.packageName}-${version.version}';

  String _downloadPath(PackageVersion version) => p.join(
      _downloadsFolder,
      _hostAsDirectoryName(version.hostUrl),
      packageVersionName(version) + '.tar.gz');

  String _extractedPath(PackageVersion version) => p.join(_extractedFolder,
      _hostAsDirectoryName(version.hostUrl), packageVersionName(version));

  Future<File> _downloadPackage(PackageVersion version) async {
    final downloadedFile = File(_downloadPath(version));
    if (!downloadedFile.existsSync()) {
      logger.fine('Downloading $version...');

      downloadedFile.parent.createSync(recursive: true);
      await runCommandAndThrowIfFailed(
          'wget', [version.archiveUrl, '-O', downloadedFile.path]);
      if (!downloadedFile.existsSync()) {
        throw StateError(
            'Downloading file appeared to succeed, but file could not be found: ${downloadedFile.path}');
      }
    } else {
      logger.fine('Using cached download for $version');
    }

    return downloadedFile;
  }

  Future<Directory> _downloadAndExtractPackage(PackageVersion version) async {
    final extractedDirectory = Directory(_extractedPath(version));
    if (!extractedDirectory.existsSync()) {
      try {
        final downloaded = await _downloadPackage(version);
        logger.finer('Extracting $version...');
        extractedDirectory.createSync(recursive: true);
        await runCommandAndThrowIfFailed('tar', [
          'xzv',
          '--directory',
          extractedDirectory.path,
          '--file',
          downloaded.path
        ]);
      } catch (_) {
        if (extractedDirectory.existsSync()) {
          extractedDirectory.deleteSync(recursive: true);
        }
        rethrow;
      }
    } else {
      logger.finer('Using already extracted folder for $version');
      final pubspecFile = File(p.join(extractedDirectory.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        throw Exception('No pubspec file found at ${pubspecFile.path}.'
            ' Either this package version is bad, or something went wrong with the download and extraction steps.'
            ' Try deleting the following files/directories and running the script again:'
            ' ${_downloadPath(version)}, ${extractedDirectory.path}');
      }
    }

    return extractedDirectory;
  }

  Future<Directory> getExtractedFolder(PackageVersion version) =>
      _downloadAndExtractPackage(version);
}

class PackageVersion {
  final String packageName;
  final String hostUrl;
  final String version;
  final String archiveUrl;

  PackageVersion({
    required this.packageName,
    required this.hostUrl,
    required this.version,
    String? archiveUrl,
  }) : archiveUrl = archiveUrl ??
            p.url.join(
                hostUrl, '/packages/$packageName/versions/$version.tar.gz');

  @override
  String toString() => '$packageName $version (from $hostUrl)';
}
