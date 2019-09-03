import 'dart:io';
import 'package:path/path.dart' as p;

/// Creates a temporary package with a `pubspec.yaml` and `main.dart` file
class DartTempProjectCreator {
  Directory dir;
  PubspecCreator pubspecCreator;
  String mainDartContents;

  DartTempProjectCreator({this.pubspecCreator, this.mainDartContents}) {
    pubspecCreator ??= PubspecCreator();
    mainDartContents ??= 'void main() {}';
    dir = Directory.systemTemp.createTempSync();
    if (pubspecCreator.createPubspecFile) {
      File(p.join(dir.path, 'pubspec.yaml'))
          .writeAsStringSync(pubspecCreator.toString());
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
  bool createPubspecFile;

  PubspecCreator(
      {this.name = 'fake_package',
      this.version = '0.0.0',
      this.isPrivate = true,
      this.sdkVersion = '">=2.4.0 <3.0.0"',
      this.dependencies = const [],
      this.createPubspecFile = true});

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

  bool includePubspecFile;

  String mainDartContents;

  PubspecCreator pubspecCreator;

  /// The dependencies to test in the pubspec.yaml.
  List<DependencyCreator> dependencies;

  DartProjectCreatorTestConfig({
    String testName,
    int expectedExitCode,
    this.dependencies,
    this.mainDartContents,
    this.pubspecCreator,
    this.shouldRunCodemod = false,
    this.includePubspecFile = true,
  }) {
    _testName = testName;

    this.expectedExitCode = expectedExitCode ?? (shouldRunCodemod ? 1 : 0);
  }

  String get testName =>
      _testName ??
      'returns exit code ${expectedExitCode ?? (shouldRunCodemod ? 1 : 0)} with dependencies: ' +
          dependencies.map((dep) => dep.toString()).join(', ');
}
