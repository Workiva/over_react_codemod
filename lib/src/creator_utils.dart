import 'dart:io';
import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:path/path.dart' as p;

/// Creates a temporary package with a `pubspec.yaml` and `main.dart` file
class DartTempProjectCreator {
  Directory dir;
  List<PubspecCreator> pubspecCreators;
  String mainDartContents;

  DartTempProjectCreator(
      {PubspecCreator pubspecCreator,
      this.pubspecCreators,
      this.mainDartContents}) {
    if (pubspecCreator != null && pubspecCreators != null) {
      throw ArgumentError(
          'Cannot specify both pubspecCreator and pubspecCreators');
    }

    pubspecCreators ??= [pubspecCreator ?? PubspecCreator()];
    mainDartContents ??= 'void main() {}';
    dir = Directory.systemTemp.createTempSync();
    for (var pubspecCreator in pubspecCreators) {
      pubspecCreator.create(dir.path);
    }
    File(p.join(dir.path, 'main.dart')).writeAsStringSync(mainDartContents);
  }
}

class PubspecCreator {
  String name;
  String version;
  bool isPrivate;
  String sdkVersion;
  List<DependencyCreator> dependencies;
  String path;

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
      {String version = 'any', bool asDev = false, bool Function() shouldAdd}) {
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
  String name;
  String version;
  String ref;
  String gitOverride;
  String pathOverride;
  bool asDev;
  bool asNonGitOrPathOverride;

  DependencyCreator(
    this.name, {
    this.version = 'any',
    this.asDev = false,
    this.asNonGitOrPathOverride = false,
    this.gitOverride = '',
    this.pathOverride = '',
    this.ref,
  }) {
    if (pathOverride.isNotEmpty && gitOverride.isNotEmpty) {
      throw ArgumentError(
          'Cannot provide both git and path overrides on single dep.');
    }
    this.version = _versionWithQuotes(version);
  }

  DependencyCreator.fromOverrideConfig(DependencyOverrideConfig config) {
    this.name = config.name;

    switch (config.type) {
      case ConfigType.simple:
        this.version =
            _versionWithQuotes((config as SimpleOverrideConfig).version);
        this.asNonGitOrPathOverride = true;
        break;
      case ConfigType.git:
        final tConfig = config as GitOverrideConfig;
        this.asNonGitOrPathOverride = false;
        this.gitOverride = tConfig.url;
        this.ref = tConfig.ref;
        break;
    }
  }

  /// Checks if the version string should have quotes ands adds them if necessary.
  String _versionWithQuotes(String version) {
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
  String _testName;

  /// Whether or not the codemod is expected to run based on the dependencies provided.
  ///
  /// default: `false`
  bool shouldRunCodemod = false;

  int expectedExitCode;

  String mainDartContents;

  List<PubspecCreator> pubspecCreators;

  DartProjectCreatorTestConfig({
    String testName,
    int expectedExitCode,
    List<DependencyCreator> dependencies,
    this.mainDartContents,
    this.pubspecCreators,
    this.shouldRunCodemod = false,
  }) {
    _testName = testName;

    if (pubspecCreators != null && dependencies != null) {
      throw ArgumentError(
          'Cannot specify both pubspecCreators and dependencies');
    }
    pubspecCreators ??= [PubspecCreator(dependencies: dependencies ?? [])];

    this.expectedExitCode = expectedExitCode ?? (shouldRunCodemod ? 1 : 0);
  }

  String get testName {
    if (_testName != null) return _testName;

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
