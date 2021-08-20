import 'package:codemod/codemod.dart';

/// A suggestor that gets called for each library with the contexts for
/// the main library and all its part files, as opposed to each file individually.
///
/// This enables writing suggestors that need to get the resolved unit for a
/// libary's part files, which isn't possible using the FileContext API.
///
/// [partContexts] will be null when the main compilation unit couldn't be resolved,
/// and elements of that list are themselves null when that part collected in the first suggestor,
/// most likely because it wasn't included in the codemod's filePaths argument.
typedef LibraryAggregateSuggestor = Stream<Patch> Function(
  FileContext libraryContext,
  List<FileContext?>? partContexts,
);

/// Returns a sequence of suggestors that collect and run [suggestor] when run
/// within [runInteractiveCodemodSequence].
///
/// Example usage:
/// ```dart
/// exitCode = await runInteractiveCodemodSequence([
///    someOtherSuggestor,
///    ..libraryAggregateSuggestorAsSequence((context, partContexts) {
///      // aggregate suggestor logic
///    }),
///    anotherSuggestor,
/// ]);
/// ```
///
/// This is necessary since we need to aggregate information on libraries and
/// their parts in a first pass before we actually run the suggestor in a second pass.
///
/// See [LibraryAggregateSuggestor] for more detail.
List<Suggestor> libraryAggregateSuggestorAsSequence(
    LibraryAggregateSuggestor suggestor) {
  final contextsByPath = <String, FileContext>{};

  final pathsPassedToAggregatingSuggestor = <String>{};
  Stream<Patch> aggregatingSuggestor(FileContext context) async* {
    if (!pathsPassedToAggregatingSuggestor.add(context.path)) {
      throw StateError('This library aggregate suggestor is stateful'
          ' and has must not be called twice for a given file.');
    }

    contextsByPath[context.path] = context;
  }

  final pathsPassedToFinalSuggestor = <String>{};
  Stream<Patch> finalSuggestor(FileContext context) async* {
    if (!pathsPassedToFinalSuggestor.add(context.path)) {
      throw StateError('This library aggregate suggestor is stateful'
          ' and has must not be called twice for a given file.');
    }

    final result = await context.getResolvedUnit();

    // Only call the suggestor for the main library, not its parts.
    if (result?.isPart ?? false) return;

    final partContexts = result?.unit?.declaredElement?.library.parts
        .map((part) => contextsByPath[part.source.fullName])
        .toList();

    yield* suggestor(context, partContexts);
  }

  return [aggregatingSuggestor, finalSuggestor];
}
