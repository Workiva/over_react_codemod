import 'dart:io';
import 'package:path/path.dart' as p;

/// Creates a temporary package with a `pubspec.yaml` and `main.dart` file
class DartProjectFaker {
  Directory dir;
  PubspecFaker pubspecFaker;
  String mainDartContents;

  DartProjectFaker({this.pubspecFaker, this.mainDartContents}) {
    pubspecFaker ??= PubspecFaker();
    mainDartContents ??= 'void main() {}';
    dir = Directory.systemTemp.createTempSync();
    if (pubspecFaker.createPubspecFile) {
      File(p.join(dir.path, 'pubspec.yaml'))
          .writeAsStringSync(pubspecFaker.toString());
    }
    File(p.join(dir.path, 'main.dart')).writeAsStringSync(mainDartContents);
  }
}

class PubspecFaker {
  String name;
  String version;
  bool isPrivate;
  String sdkVersion;
  List<DependencyFaker> dependencies;
  bool createPubspecFile;

  PubspecFaker(
      {this.name = 'fake_package',
      this.version = '0.0.0',
      this.isPrivate = true,
      this.sdkVersion = '">=2.4.0 <3.0.0"',
      this.dependencies = const [],
      this.createPubspecFile = true});

  void removeDependencyWhere(bool Function(DependencyFaker) callback) {
    dependencies.removeWhere(callback);
  }

  void addDependencies(List<DependencyFaker> new_dependencies) {
    dependencies.addAll(new_dependencies);
  }

  void addDependency(String name,
      {String version = 'any', bool asDev = false, bool Function() shouldAdd}) {
    if (shouldAdd?.call() ?? true) {
      dependencies.add(DependencyFaker(name, version: version, asDev: asDev));
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

class DependencyFaker {
  String name;
  String version;
  String ref;
  String gitOverride;
  String pathOverride;
  bool asDev;

  DependencyFaker(
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
class DartProjectFakerTestConfig {
  String _testName;

  /// Wether or not the codemod is expected to run based on the dependencies provided.
  ///
  /// default: `false`
  bool shouldRunCodemod = false;

  int expectedExitCode;

  bool includePubspecFile;

  String mainDartContents;

  PubspecFaker pubspecFaker;

  /// The dependencies to test in the pubspec.yaml.
  List<DependencyFaker> dependencies;

  DartProjectFakerTestConfig({
    String testName,
    int expectedExitCode,
    this.dependencies,
    this.mainDartContents,
    this.pubspecFaker,
    this.shouldRunCodemod = false,
    this.includePubspecFile = true,
  }) {
    _testName = testName;

    this.expectedExitCode = expectedExitCode ?? (shouldRunCodemod ? 1 : 0);
  }

  String get testName =>
      _testName ??
      ((shouldRunCodemod ? 'runs' : 'does not run') +
          ' the codemod with dependencies: ' +
          dependencies
              .map((dep) =>
                  dep.toString().trim().replaceAll(': ', ' on version '))
              .join(', '));
}
