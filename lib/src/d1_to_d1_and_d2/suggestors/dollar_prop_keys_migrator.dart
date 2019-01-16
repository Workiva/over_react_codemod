import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

/// Suggestor that migrates usages of `$PropKeys()` to the Dart 2-compatible
/// alternative of accessing the keys off of the static `meta` field on the
/// props class.
class DollarPropKeysMigrator implements Suggestor {
  static final RegExp dollarPropKeysPattern = RegExp(
    // constructor keyword + at least one whitespace char
    r'(?:const|new)\s+'
        // optional over_react import prefix + optional whitespace
        r'(?:\w+\s*\.\s*)?'
        // $PropKeys constructor + optional whitespace
        r'\$PropKeys\s*'
        // opening paren + optional whitespace
        r'\(\s*'
        // props arg, including optional import prefix
        // (GROUP 2)
        r'([\w$.]+)'
        // optional whitespace + optional trailing comma + optional whitespace
        r'\s*(?:,)?\s*'
        // closing paren
        r'\)',
  );

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    for (final match
        in dollarPropKeysPattern.allMatches(sourceFile.getText(0))) {
      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        '${match.group(1)}.meta.keys',
      );
    }
  }

  bool shouldSkip(_) => false;
}
