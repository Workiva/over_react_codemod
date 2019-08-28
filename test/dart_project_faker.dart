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

    try {
      dir = Directory.systemTemp.createTempSync();
      if (pubspecFaker.createPubspecFile) {
        File(p.join(dir.path, 'pubspec.yaml'))
            .writeAsStringSync(pubspecFaker.toString());
      }
      File(p.join(dir.path, 'main.dart')).writeAsStringSync(mainDartContents);
    } catch (e) {
      print(e);
    }
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

  void removeDependencyWhere(Function callback) {
    dependencies.removeWhere(callback);
  }

  void addDependencies(List<DependencyFaker> new_dependencies) {
    dependencies.addAll(new_dependencies);
  }

  void addDependency(String name,
      {String version = 'any', bool asDev = false, bool Function() shouldAdd}) {
    if ((shouldAdd != null && shouldAdd() == false) ? false : true) {
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
            ? 'dependencies: \n' +
                dependencies
                    .where((dep) => dep.asDev == false)
                    .map((dep) => dep.toString())
                    .join('\n')
            : '') +
        (dependencies.isNotEmpty &&
                (dependencies.firstWhere((dep) => dep.asDev == true,
                        orElse: () => null) !=
                    null)
            ? 'dev_dependencies: \n' +
                dependencies
                    .where((dep) => dep.asDev == true)
                    .map((dep) => dep.toString())
                    .join('\n')
            : '') +
        '\n';
  }
}

class DependencyFaker {
  String name;
  String version;
  bool asDev;

  DependencyFaker(this.name, {this.version = 'any', this.asDev = false}) {
    // Check if the version string is wrapped with quotes or not and if not add them.
    if (version.contains(RegExp('[\>\<\=\ ]')) &&
        !version.startsWith(RegExp('[\'\"]'))) {
      this.version = '"' + version + '"';
    }
  }

  @override
  String toString() {
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

  int _expectedExitCode;
  set expectedExitCode(int v) => _expectedExitCode = v;
  int get expectedExitCode => _expectedExitCode ?? (shouldRunCodemod ? 1 : 0);

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
    if (testName != null) {
      _testName = testName;
    }
    if (expectedExitCode != null) {
      _expectedExitCode = expectedExitCode;
    }
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
