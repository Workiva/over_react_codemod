import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

/// Suggestor that wraps an existing suggestor and hides patches that are
/// ignored via a `// orcm_ignore` comment.
///
/// Any patch that is suggested by the given suggestor that starts on a line
/// with the ignore comment or on a line immediately after a line with the
/// ignore comment will be ignored. All other patches will be re-yielded via
/// [generatePatches].
class Ignoreable implements Suggestor {
  static RegExp _ignoreRegex =
      RegExp(r'//[ ]*orcm_ignore[ ]*$', multiLine: true);

  final Suggestor _suggestor;

  Ignoreable(Suggestor suggestor) : _suggestor = suggestor;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final ignoreLines = _ignoreRegex
        .allMatches(sourceFile.getText(0))
        .map((match) => sourceFile.getLine(match.start));

    yield* _suggestor
        .generatePatches(sourceFile)
        // Skip patches that start on a line (or on a line immediately after a
        // line) with an `// orcm_ignore` comment.
        .where((patch) =>
            !ignoreLines.contains(patch.startLine) &&
            !ignoreLines.contains(patch.startLine - 1));
  }

  @override
  bool shouldSkip(String sourceFileContents) =>
      _suggestor.shouldSkip(sourceFileContents);
}
