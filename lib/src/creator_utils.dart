import 'dart:io';
import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:path/path.dart' as p;

/// Creates a temporary package with a `pubspec.yaml` and `main.dart` file
class DartTempProjectCreator {
  late Directory dir;
  late List<PubspecCreator> pubspecCreators;
  late String mainDartContents;

  // fixme null-safety fix args
  DartTempProjectCreator(
      {PubspecCreator? pubspecCreator,
      List<PubspecCreator>? pubspecCreators,
      String? mainDartContents}) {
    if (pubspecCreator != null && pubspecCreators != null) {
      throw ArgumentError(
          'Cannot specify both pubspecCreator and pubspecCreators');
    }

    this.pubspecCreators =
        pubspecCreators ?? [pubspecCreator ?? PubspecCreator()];
    this.mainDartContents = mainDartContents ?? 'void main() {}';
    dir = Directory.systemTemp.createTempSync();
    for (var pubspecCreator in pubspecCreators!) {
      pubspecCreator.create(dir.path);
    }
    File(p.join(dir.path, 'main.dart')).writeAsStringSync(this.mainDartContents);
  }
}

class PubspecCreator {
  final String name;
  final String version;
  final bool isPrivate;
  final String sdkVersion;
  final List<DependencyCreator> dependencies;
  final String path;

  PubspecCreator(
      {this.name = 'fake_package',
      this.version = '0.0.0',
      this.isPrivate = true,
      this.sdkVersion = '">=2.4.0 <3.0.0"',
      this.dependencies = const [],
      this.path = ''});

  void create(String rootDir) {
    final parentDir = p.join(rootDir, path);
    Directory(parentDir).createSync(recursive: true);
    File(p.join(parentDir, 'pubspec.yaml')).writeAsStringSync(toString());
  }

  void removeDependencyWhere(bool Function(DependencyCreator) callback) {
    dependencies.removeWhere(callback);
  }

  void addDependencies(List<DependencyCreator> new_dependencies) {
    dependencies.addAll(new_dependencies);
  }

  void addDependency(String name,
      {String version = 'any', bool asDev = false, bool Function()? shouldAdd}) {
    if (shouldAdd?.call() ?? true) {
      dependencies.add(DependencyCreator(name, version: version, asDev: asDev));
    }
  }

  void addDevDependency(String name, {String version = 'any'}) {
    addDependency(name, version: version, asDev: true);
  }

  @override
  String toString() {
    return 'name: $name\n' +
        'version: $version\n' +
        'private: $isPrivate\n' +
        'environment:\n' +
        '  sdk: $sdkVersion\n' +
        (dependencies.isNotEmpty
            ? '\ndependencies: \n' +
                dependencies
                    .where((dep) => !(dep.asDev || dep.asOverride))
                    .join('\n')
            : '') +
        (dependencies.any((dep) => dep.asDev)
            ? '\ndev_dependencies: \n' +
                dependencies.where((dep) => dep.asDev).join('\n')
            : '') +
        (dependencies.any((dep) => dep.asOverride)
            ? '\ndependency_overrides: \n' +
                dependencies.where((dep) => dep.asOverride).join('\n')
            : '') +
        '\n';
  }
}

class DependencyCreator {
  final String name;
  final String version;
  final String? ref;
  final String gitOverride;
  final String pathOverride;
  final bool asDev;
  final bool asNonGitOrPathOverride;

  DependencyCreator(
    this.name, {
    String version = 'any',
    this.asDev = false,
    this.asNonGitOrPathOverride = false,
    this.gitOverride = '',
    this.pathOverride = '',
    this.ref,
  }) : version = _versionWithQuotes(version) {
    if (pathOverride.isNotEmpty && gitOverride.isNotEmpty) {
      throw ArgumentError(
          'Cannot provide both git and path overrides on single dep.');
    }
  }

  factory DependencyCreator.fromOverrideConfig(
      DependencyOverrideConfig config) {
    switch (config.type) {
      case ConfigType.simple:
        return DependencyCreator(
          config.name,
          version: (config as SimpleOverrideConfig).version,
          asNonGitOrPathOverride: true,
        );
        break;
      case ConfigType.git:
        final tConfig = config as GitOverrideConfig;
        return DependencyCreator(
          tConfig.name,
          asNonGitOrPathOverride: false,
          gitOverride: tConfig.url,
          ref: tConfig.ref,
        );
        break;
    }

    throw ArgumentError.value(config.type, 'config.type');
  }

  /// Checks if the version string should have quotes ands adds them if necessary.
  static String _versionWithQuotes(String version) {
    if (version.contains(RegExp('[\>\<\=\ ]')) &&
        !version.startsWith(RegExp('[\'\"]'))) {
      return '"' + version + '"';
    }

    return version;
  }

  bool get asOverride =>
      asNonGitOrPathOverride ||
      gitOverride.isNotEmpty ||
      pathOverride.isNotEmpty;

  @override
  String toString() {
    if (asOverride && !asNonGitOrPathOverride) {
      var temp = '  $name:\n';
      if ((gitOverride?.isNotEmpty) ?? false) {
        temp += '    git:\n      url: $gitOverride\n';
      }
      if ((pathOverride?.isNotEmpty) ?? false) {
        temp += '    path: $pathOverride\n';
      }
      if (ref != null) temp += '      ref: $ref\n';
      return temp;
    }
    return '  $name: $version\n';
  }
}

/// A test helper class to configure versions of a pubspec to test
class DartProjectCreatorTestConfig {
  final String? _testName;

  /// Whether or not the codemod is expected to run based on the dependencies provided.
  ///
  /// default: `false`
  final bool shouldRunCodemod;

  final int expectedExitCode;

  final String? mainDartContents;

  late List<PubspecCreator> pubspecCreators;

  DartProjectCreatorTestConfig({
    String? testName,
    int? expectedExitCode,
    List<DependencyCreator>? dependencies,
    this.mainDartContents,
    List<PubspecCreator>? pubspecCreators,
    this.shouldRunCodemod = false,
  })  : _testName = testName,
        expectedExitCode = expectedExitCode ?? (shouldRunCodemod ? 1 : 0) {
    if (pubspecCreators != null && dependencies != null) {
      throw ArgumentError(
          'Cannot specify both pubspecCreators and dependencies');
    }
    this.pubspecCreators =
        pubspecCreators ?? [PubspecCreator(dependencies: dependencies ?? [])];
  }

  String get testName {
    if (_testName != null) return _testName!;

    var name =
        'returns exit code ${expectedExitCode ?? (shouldRunCodemod ? 1 : 0)} with ';
    if (pubspecCreators.isEmpty) {
      name += 'no pubspecs';
    } else {
      name += pubspecCreators.map((creator) {
        // Make it so that test names aren't multiline, trim/consolidate whitespace.
        final humanReadableDependencies = creator.dependencies
            .map((dep) => dep
                .toString()
                .trim()
                .replaceAll('\n', '\\n')
                .replaceAll(RegExp(r' +'), ' '))
            .toList();
        return 'pubspec'
            ' at ${creator.path.isEmpty ? 'root' : 'path ${creator.path}/pubspec.yaml'}'
            ' with dependencies: ${humanReadableDependencies}';
      }).join(', ');
    }
    return name;
  }
}
