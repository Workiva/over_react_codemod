import 'dart:io';
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
      throw new ArgumentError(
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

  DependencyCreator(
    this.name, {
    this.version = 'any',
    this.asDev = false,
    this.gitOverride = '',
    this.pathOverride = '',
    this.ref,
  }) {
    if (pathOverride.isNotEmpty && gitOverride.isNotEmpty) {
      throw ArgumentError(
          'Cannot provide both git and path overrides on single dep.');
    }
    // Check if the version string is wrapped with quotes or not and if not add them.
    if (version.contains(RegExp('[\>\<\=\ ]')) &&
        !version.startsWith(RegExp('[\'\"]'))) {
      this.version = '"' + version + '"';
    }
  }

  bool get asOverride => (gitOverride.isNotEmpty || pathOverride.isNotEmpty);

  @override
  String toString() {
    if (asOverride) {
      var temp = '  $name:\n';
      if (gitOverride.isNotEmpty) temp += '    git:\n      url: $gitOverride\n';
      if (pathOverride.isNotEmpty) temp += '    path: $pathOverride\n';
      if (ref != null) temp += '      ref: $ref\n';
      return temp;
    }
    return '  $name: $version';
  }
}

/// A test helper class to configure versions of a pubspec to test
class DartProjectCreatorTestConfig {
  String _testName;

  /// Wether or not the codemod is expected to run based on the dependencies provided.
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
      throw new ArgumentError(
          'Cannot specify both pubspecCreators and dependencies');
    }
    pubspecCreators ??= [new PubspecCreator(dependencies: dependencies ?? [])];

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
        return 'pubspec at ${creator.path.isEmpty ? 'root' : 'path ${creator.path}'} '
            'with dependencies: ${creator.dependencies.join(', ')}';
      }).join(';');
    }
    return name;
  }
}
