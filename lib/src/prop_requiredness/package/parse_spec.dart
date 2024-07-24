import 'dart:io';

import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/git.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/local.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/pub.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/spec.dart';
import 'package:over_react_codemod/src/prop_requiredness/package/version_manager.dart';

Future<PackageSpec> parsePackageSpec(
  String packageSpecString, {
  required PackageVersionManager Function() getVersionManager,
}) async {
  Never invalidPackageSpec([String additionalMessage = '']) =>
      throw PackageSpecParseException('''
Could not resolve package spec '$packageSpecString'.$additionalMessage 

Allowed formats: 
- Hosted pub package with optional version (uses latest if omitted):
   - `pub@pub.dev:over_react`
   - `pub@pub.dev:over_react#5.2.0`
- Git URL with optional revision:  
    - `git@github.com:Workiva/over_react.git`
    - `https://github.com/Workiva/over_react.git`
    - `git@github.com:Workiva/over_react.git#5.2.0`
- Local file path:
    - `/path/to/over_react`
    - `file:///path/to/over_react`''');

  final uri = Uri.tryParse(packageSpecString);
  if ((uri != null && uri.isScheme('https://')) ||
      packageSpecString.startsWith('git@')) {
    final parts = packageSpecString.split('#');
    final repoUrl = parts[0];
    var ref = parts.skip(1).firstOrNull ?? '';
    if (ref.isEmpty) ref = 'HEAD';
    return gitRefPackageSpec(repoUrl, ref);
  }

  if (packageSpecString.startsWith('pub@')) {
    final pattern = RegExp(r'pub@(.+):(\w+)(?:#(.+))?$');
    final match = pattern.firstMatch(packageSpecString);
    if (match == null) {
      throw Exception(
          "Pub formats must be 'pub@<package-host>:<package-name>(#version)'");
    }
    var host = match[1]!;
    if (!Uri.parse(host).hasScheme) {
      host = 'https://$host';
    }
    final packageName = match[2]!;
    final version = match[3] ?? '';
    return pubPackageSpec(
      packageName: packageName,
      version: version.isEmpty ? null : version,
      versionManager: getVersionManager(),
      host: host.toString(),
    );
  }

  if (uri != null && (!uri.hasScheme || uri.isScheme('file'))) {
    final path = uri.toFilePath();
    if (!Directory(path).existsSync()) {
      invalidPackageSpec(' If this is local path, it does not exist.');
    }
    return localPathPackageSpec(path);
  }

  invalidPackageSpec();
}

class PackageSpecParseException implements Exception {
  final String message;

  PackageSpecParseException(this.message);

  @override
  String toString() => 'PackageSpecParseException: $message';
}
