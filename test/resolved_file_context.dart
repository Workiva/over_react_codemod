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

final _testFixturePath =
    p.join(findPackageRootFor(p.current), 'test/test_fixtures');

class SharedAnalysisContext {
  static final overReact =
      SharedAnalysisContext(p.join(_testFixturePath, 'over_react_project'));

  static final wsd =
      SharedAnalysisContext(p.join(_testFixturePath, 'wsd_project'));

  final String projectRoot;
  late final AnalysisContextCollection collection;
  bool _isInitialized = false;

  SharedAnalysisContext(this.projectRoot) {
    if (!p.isAbsolute(projectRoot)) {
      throw ArgumentError.value(projectRoot, 'projectRoot', 'must be absolute');
    }
  }

  static const _testFileSubpath = 'lib/dynamic_test_files';

  Future<void> _initIfNeeded() async {
    if (!_isInitialized) {
      print('Cleaning up files from previous runs...');
      Directory(p.join(projectRoot, _testFileSubpath))
          .deleteSyncIfExists(recursive: true);

      await runPubGetIfNeeded(projectRoot);

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
    print('Warming up the AnalysisContextCollection...');
    final path = p.join(projectRoot, 'lib/analysis_warmup.dart');
    await collection.contextFor(path).currentSession.getResolvedLibrary2(path);
    print('Done.');
    _shouldPrintFirstFileWarning = false;
  }

  Future<List<Patch>> getPatches(
    Suggestor suggestor,
    String sourceText, {
    String? filename,
    bool preResolveFile = true,
    bool throwOnAnalysisErrors = true,
  }) async {
    final context = await resolvedFileContextForTest(
      sourceText,
      preResolveFile: preResolveFile,
      throwOnAnalysisErrors: throwOnAnalysisErrors,
      filename: filename,
    );
    return await suggestor(context).toList();
  }

  Future<FileContext> resolvedFileContextForTest(
    String sourceText, {
    String? filename,
    bool includeTestDescription = true,
    bool preResolveFile = true,
    bool throwOnAnalysisErrors = true,
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
          // fixme implement some sort of file lock/mutex to avoid this?
          ' This error can also occcur if there are concurrent test runs');
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(sourceText);

    final context = collection.contexts
        .singleWhere((c) => c.contextRoot.root.path == projectRoot);

    if (throwOnAnalysisErrors && !preResolveFile) {
      throw ArgumentError(
          'If throwOnAnalysisErrors is false, preResolveFile must be true');
    }
    if (preResolveFile) {
      final result = await _printAboutFirstFile(
          () => context.currentSession.getResolvedLibrary2(path));
      if (throwOnAnalysisErrors) {
        checkResolvedResultForErrors(result);
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
      print('Resolving a file for the first time in this context;'
          ' this will take a few seconds...');
    }
    final result = await callback();
    if (shouldPrint) {
      print('Done resolving.');
    }
    return result;
  }
}

bool _defaultIsExpectedError(_) => false;

void checkResolvedResultForErrors(
  SomeResolvedLibraryResult result, {
  bool Function(AnalysisError) isExpectedError = _defaultIsExpectedError,
}) {
  const sharedMessage =
      'If analysis errors are expected for this test, set `throwOnAnalysisErrors: false`,'
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
      .where((error) => !isExpectedError(error))
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
