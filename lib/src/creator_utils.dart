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
      dependencies.add(DependencyCreator(name, version: version, isDev: asDev));
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
                    .where((dep) => !(dep.isDev || dep.isOverride))
                    .join('\n')
            : '') +
        (dependencies.any((dep) => dep.isDev)
            ? '\ndev_dependencies: \n' +
                dependencies.where((dep) => dep.isDev).join('\n')
            : '') +
        (dependencies.any((dep) => dep.isOverride)
            ? '\ndependency_overrides: \n' +
                dependencies.where((dep) => dep.isOverride).join('\n')
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
  bool isDev;
  int indentAmount;

  DependencyCreator(
    this.name, {
    this.version = 'any',
    this.isDev = false,
    this.gitOverride = '',
    this.pathOverride = '',
    this.ref,
    this.indentAmount = 2,
  }) {
    if (pathOverride.isNotEmpty && gitOverride.isNotEmpty) {
      throw ArgumentError(
          'Cannot provide both git and path overrides on single dep.');
    }
  }

  String indentByLevel([level = 1]) {
    return (' ' * (indentAmount*level));
  }

  String versionForOutput({String versionPrefix = " ", String overridePrefix = '\n', bool includeInitalIndent = true}){
    if (version.contains(RegExp('[\>\<\=\ ]')) &&
        !version.startsWith(RegExp('[\'\"]'))) {
      return '$versionPrefix"' + version + '"';
    } else if (isOverride) {
      var temp = '$overridePrefix';
      if (gitOverride.isNotEmpty) temp += '''${includeInitalIndent ? indentByLevel(2) : ''}git:\n${indentByLevel(3)}url: $gitOverride\n''';
      if (pathOverride.isNotEmpty) temp += '''${includeInitalIndent ? indentByLevel(2) : ''}path: $pathOverride\n''';
      if (ref != null) temp += '''${indentByLevel(3)}ref: $ref\n''';
      return temp;
    }
    return version;
  }

  String get section {
    if (isDev) return 'dev_dependencies';
    if (isOverride) return 'dependency_overrides';
    return 'dependencies';
  }

  bool get isOverride => (gitOverride.isNotEmpty || pathOverride.isNotEmpty);

  @override
  String toString() {
    return '${indentByLevel(1)}$name:${versionForOutput()}';
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
      name += pubspecCreators
          .map((creator) => 'pubspec'
              ' at ${creator.path.isEmpty ? 'root' : 'path ${creator.path}/pubspec.yaml'}'
              ' with dependencies: ${creator.dependencies}')
          .join(', ');
    }
    return name;
  }
}
