import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;

class SharedAnalysisContext {
  // fixme don't hardcode this
  final projectRoot = '/Users/greglittlefield/workspaces/over_react_codemod/'
      'test/test_fixtures/wsd_project';

  static const testFileSubpath = 'lib/dynamic_test_files';

  late AnalysisContextCollection collection;

  static const warmUpAnalysis = false;

  Future<void> init() async {
    if (!p.isAbsolute(projectRoot)) {
      throw ArgumentError.value(projectRoot, 'projectRoot', 'must be absolute');
    }

    print('Cleaning up old files...');
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

  Future<List<Patch>> getPatches(Suggestor suggestor, String sourceText,
      {String? filename}) async {
    final context = await resolvedFileContextForTest(sourceText);
    return await suggestor(context).toList();
  }

  Future<FileContext> resolvedFileContextForTest(String sourceText,
      {String? filename}) async {
    filename ??= nextFilename();

    final path = p.join(projectRoot, testFileSubpath, filename);
    final file = File(path);
    if (file.existsSync()) {
      throw StateError('File already exists.'
          ' Cannot use an existing file, since there is no public API'
          ' to update a file within a AnalysisContextCollection.'
          ' Use a unique filename each time.');
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(sourceText);

    final context = collection.contexts
        .singleWhere((c) => c.contextRoot.root.path == projectRoot);
    // Resolve the file so that calls to AnalysisContextCollection.contextFor don't throw a StateError.
    await _printAboutFirstFile(
        () => context.currentSession.getResolvedLibrary2(path));
    // Verify that this doesn't throw.
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
      print(
          'Resolving a file for the first time. This may take a few seconds...');
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
