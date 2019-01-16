import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

/// Suggestor that migrates usages of the `getDefaultProps()` method on a
/// UI component class to the Dart 2-compatible alternative of using the
/// `componentDefaultProps` getter on the component's props class.
class ComponentDefaultPropsMigrator implements Suggestor {
  static final RegExp dollarPropsPattern = RegExp(
      // constructor keyword + at least one whitespace char
      r'new\s+'
      // component class name
      // (GROUP 1)
      r'(\w+)Component'
      // parens + optional whitespace
      r'\(\)\s*'
      // getDefaultProps() invocation
      r'\.getDefaultProps\(\)');

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    for (final match in dollarPropsPattern.allMatches(sourceFile.getText(0))) {
      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        '${match.group(1)}().componentDefaultProps',
      );
    }
  }

  bool shouldSkip(_) => false;
}
