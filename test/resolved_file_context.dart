import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;

// This isn't strictly required for anything, so if the import becomes invalid,
// just comment it and related code out.
import 'package:test_api/src/backend/invoker.dart' show Invoker;
import 'package:uuid/uuid.dart';

final _testFixturePath =
    p.join(findPackageRootFor(p.current), 'test/test_fixtures');

class SharedAnalysisContext {
  static final overReact =
      SharedAnalysisContext(p.join(_testFixturePath, 'over_react_project'));

  static final wsd = SharedAnalysisContext(
      p.join(_testFixturePath, 'wsd_project'),
      customPubGetErrorMessage:
          'If this fails to resolve in GitHub Actions, make sure your test or'
          ' test group is tagged with "wsd" so that it\'s only run in Skynet.');

  final String projectRoot;
  late final AnalysisContextCollection collection;
  final String? customPubGetErrorMessage;

  SharedAnalysisContext(this.projectRoot, {this.customPubGetErrorMessage}) {
    if (!p.isAbsolute(projectRoot)) {
      throw ArgumentError.value(projectRoot, 'projectRoot', 'must be absolute');
    }
  }

  final String _uuid = Uuid().v4();

  // Namespace the test path using a UUID so that concurrent runs
  // don't try to output the same filename, making it so that we can
  // easily create new filenames by counting synchronously [nextFilename]
  // without coordinating with other test processes.
  //
  // This also allows us to keep using the same project directory among concurrent tests
  // and across test runs, which means the Dart analysis server can use cached
  // analysis results (meaning faster test runs).
  String get _testFileSubpath => 'lib/dynamic_test_files/$_uuid';

  bool _isInitialized = false;

  Future<void> _initIfNeeded() async {
    if (!_isInitialized) {
      // Note that if tests are run concurrently, then concurrent pub gets will be run.
      // This is hard to avoid (trying to avoid it using a filesystem lock in
      // macOS/Linux doesn't work due to advisory lock behavior),
      // and it **shouldn't** cause any issues, so for now we'll just let that happen.
      try {
        await runPubGetIfNeeded(projectRoot);
      } catch (_) {
        if (customPubGetErrorMessage != null) {
          print(customPubGetErrorMessage);
        }
        rethrow;
      }

      collection = AnalysisContextCollection(
        includedPaths: [projectRoot],
      );

      _isInitialized = true;
    }
  }

  /// Warms up the AnalysisContextCollection by getting the resolved library for
  /// `lib/analysis_warmup.dart` in the project.
  ///
  /// This is useful to run in a setUpAll so that the first test resolving a file
  /// doesn't take abnormally long (e.g., if having consistent test times is
  /// important, or if the first test might have a short timeout).
  Future<void> warmUpAnalysis() async {
    await _initIfNeeded();
    final path = p.join(projectRoot, 'lib/analysis_warmup.dart');
    await collection.contextFor(path).currentSession.getResolvedLibrary2(path);
    _shouldPrintFirstFileWarning = false;
  }

  Future<List<Patch>> getPatches(
    Suggestor suggestor,
    String sourceText, {
    String? filename,
    bool preResolveLibrary = true,
    bool throwOnAnalysisErrors = true,
  }) async {
    final context = await resolvedFileContextForTest(
      sourceText,
      preResolveLibrary: preResolveLibrary,
      throwOnAnalysisErrors: throwOnAnalysisErrors,
      filename: filename,
    );
    return await suggestor(context).toList();
  }

  Future<FileContext> resolvedFileContextForTest(
    String sourceText, {
    String? filename,
    bool includeTestDescription = true,
    bool preResolveLibrary = true,
    bool throwOnAnalysisErrors = true,
    IsExpectedError? isExpectedError,
  }) async {
    await _initIfNeeded();

    filename ??= nextFilename();

    if (includeTestDescription) {
      // For convenience, include the current test description in the file as
      // a comment, so that:
      // - you can tell you're looking at the right file for a given test
      // - you can search for the test description to easily find the right file
      try {
        final testName = Invoker.current!.liveTest.test.name;
        sourceText =
            lineComment('Created within test with name:\n> $testName') +
                '\n' +
                sourceText;
      } catch (_) {}
    }

    final path = p.join(projectRoot, _testFileSubpath, filename);
    final file = File(path);
    if (file.existsSync()) {
      throw StateError('File already exists: ${filename}.'
          ' Cannot use an existing file, since there is no public API'
          ' to update a file within a AnalysisContextCollection.'
          ' Make sure you\'re using a unique filename each time.'
          ' This error can also occur if there are concurrent test runs'
          ' and `_testFileSubpath` is not namespaced.');
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(sourceText);

    final context = collection.contexts
        .singleWhere((c) => c.contextRoot.root.path == projectRoot);

    if (throwOnAnalysisErrors && !preResolveLibrary) {
      throw ArgumentError(
          'If throwOnAnalysisErrors is true, preResolveFile must be false');
    }
    if (preResolveLibrary) {
      final result = await _printAboutFirstFile(
          () => context.currentSession.getResolvedLibrary2(path));
      if (throwOnAnalysisErrors) {
        checkResolvedResultForErrors(result, isExpectedError: isExpectedError);
      }
    }

    // Assert that this doesn't throw a StateError due to this file not
    // existing in the context we've set up (which shouldn't ever happen).
    collection.contextFor(path);

    return FileContext(path, collection, root: projectRoot);
  }

  int _fileNameCounter = 0;

  String nextFilename() => 'test_${_fileNameCounter++}.dart';

  bool _shouldPrintFirstFileWarning = true;

  /// We can't intelligently warn only when this is taking too long since
  /// getResolvedLibrary2 blocks the main thread for a long period of time,
  /// making it so that timers don't fire until it's done.
  /// So, we'll just always print this.
  Future<T> _printAboutFirstFile<T>(Future<T> callback()) async {
    var shouldPrint = false;
    if (_shouldPrintFirstFileWarning) {
      _shouldPrintFirstFileWarning = false;
      shouldPrint = true;
    }

    if (shouldPrint) {
      final contextName = p.basename(projectRoot);
      print('Resolving a file for the first time in context "${contextName}";'
          ' this will take a few seconds...');
    }
    final result = await callback();
    if (shouldPrint) {
      print('Done resolving.');
    }
    return result;
  }
}

typedef IsExpectedError = bool Function(AnalysisError);

void checkResolvedResultForErrors(
  SomeResolvedLibraryResult result, {
  IsExpectedError? isExpectedError,
}) {
  isExpectedError ??= (_) => false;

  const sharedMessage = 'If analysis errors are expected for this test, either:'
      '\n1. use an `ignore:` comment to silence them'
      '\n2. set `throwOnAnalysisErrors: false`,'
      ' and use `checkResolvedResultForErrors` with `isExpectedError`'
      ' to verify that only the expected errors are present.';

  if (result is! ResolvedLibraryResult) {
    throw ArgumentError([
      'Error resolving file; result was ${result}.',
      sharedMessage
    ].join(' '));
  }

  final units = result.units;
  if (units == null) {
    throw ArgumentError([
      'Error resolving file; units was null. Result: ${result}.',
      sharedMessage
    ].join(' '));
  }

  bool isUnusedError(AnalysisError error) => const {
        'unused_element',
        'unused_local_variable'
      }.contains(error.errorCode.name.toLowerCase());

  final unexpectedErrors = units
      .expand((unit) => unit.errors)
      .where(
          (error) => error.severity == Severity.error || isUnusedError(error))
      // We need a non-null-assertion here due to https://github.com/dart-lang/sdk/issues/40790
      .where((error) => !isExpectedError!(error))
      .toList();
  if (unexpectedErrors.isNotEmpty) {
    throw ArgumentError([
      // ignore: no_adjacent_strings_in_list
      'File had analysis errors or unused element hints, which likely indicate that the test file is set up improperly,'
          ' potentially resulting in false positives in your test.',
      sharedMessage,
      'Errors:\n${prettyPrintErrors(unexpectedErrors)}.'
    ].join(' '));
  }
}

extension FileSystemDeleteIfExistExtension on FileSystemEntity {
  void deleteSyncIfExists({bool recursive = false}) {
    if (existsSync()) {
      deleteSync(recursive: recursive);
    }
  }

  Future<void> deleteIfExists({bool recursive = false}) async {
    if (existsSync()) {
      await delete(recursive: recursive);
    }
  }
}
