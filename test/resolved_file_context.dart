import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:codemod/codemod.dart';
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

  SharedAnalysisContext(this.projectRoot) {
    if (!p.isAbsolute(projectRoot)) {
      throw ArgumentError.value(projectRoot, 'projectRoot', 'must be absolute');
    }
  }

  static const testFileSubpath = 'lib/dynamic_test_files';

  late AnalysisContextCollection collection;

  static const warmUpAnalysis = false;

  Future<void> init() async {
    print('Cleaning up old files...');
    // fixme throw state error if this is called twice. Perhaps run this automatically?
    Directory(p.join(projectRoot, testFileSubpath))
        .deleteSyncIfExists(recursive: true);

    await runPubGetIfNeeded(projectRoot);

    collection = AnalysisContextCollection(
      includedPaths: [projectRoot],
    );
    if (warmUpAnalysis) {
      print('Warming up up AnalysisContextCollection...');
      final path = p.join(projectRoot, 'lib/analysis_warmup.dart');
      await collection
          .contextFor(path)
          .currentSession
          .getResolvedLibrary2(path);
      print('Done.');
    }
  }

  Future<List<Patch>> getPatches(
    Suggestor suggestor,
    String sourceText, {
    String? filename,
    bool preResolveFile = true,
  }) async {
    final context = await resolvedFileContextForTest(
      sourceText,
      preResolveFile: preResolveFile,
      filename: filename,
    );
    return await suggestor(context).toList();
  }

  Future<FileContext> resolvedFileContextForTest(
    String sourceText, {
    String? filename,
    bool includeTestDescription = true,
    bool preResolveFile = true,
  }) async {
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

    final path = p.join(projectRoot, testFileSubpath, filename);
    final file = File(path);
    if (file.existsSync()) {
      throw StateError('File already exists.'
          ' Cannot use an existing file, since there is no public API'
          ' to update a file within a AnalysisContextCollection.'
          ' Make sure you\'re calling init() first, and that you\'re using'
          ' a unique filename each time.');
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(sourceText);

    final context = collection.contexts
        .singleWhere((c) => c.contextRoot.root.path == projectRoot);

    if (preResolveFile) {
      await _printAboutFirstFile(
          () => context.currentSession.getResolvedLibrary2(path));
    }

    // Assert that this doesn't throw a StateError due to this file not
    // existing in the context we've set up (which shouldn't ever happen).
    collection.contextFor(path);

    return FileContext(path, collection, root: projectRoot);
  }

  int _fileNameCounter = 0;

  String nextFilename() => 'test_${_fileNameCounter++}.dart';

  bool _shouldPrintFirstFileWarning = !warmUpAnalysis;

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
