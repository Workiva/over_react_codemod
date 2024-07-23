import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'spec.dart';

PackageSpec localPathPackageSpec(String packageRoot) {
  final packageName = (loadYamlNode(
          File(p.join(packageRoot, 'pubspec.yaml')).readAsStringSync())
      as YamlMap)['name'] as String;
  return PackageSpec(
    packageName: packageName,
    versionId: 'local-path',
    sourceDescription: 'local path',
    getDirectory: () async => Directory(packageRoot),
  );
}
