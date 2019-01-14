import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:path/path.dart' as p;

import '../../util.dart';
import 'over_react_generated_part_directive_adder.dart';

/// Suggestor that collects the set of libraries that need an over_react
/// generated part file.
///
/// This suggestor is intended to be used in conjunction with the
/// [OverReactGeneratedPartDirectiveAdder]; this collector should run first
/// across the entire set of Dart files in a project and then the directive
/// adder should run second (using [runInteractiveCodemodSequence]).
class NeedsOverReactLibraryCollector extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  /// Libraries (by name) that need the over_react generated part directive.
  Iterable<String> get byName => List.unmodifiable(_byName);
  final Set<String> _byName = Set<String>();

  /// Libraries (by path) that need the over_react generated part directive.
  Iterable<String> get byPath => List.unmodifiable(_byPath);
  final Set<String> _byPath = Set<String>();

  bool _hasPartOfDirective;

  @override
  visitCompilationUnit(CompilationUnit node) {
    // Reset this flag, as it is specific to each source file/compilation unit.
    _hasPartOfDirective = false;

    // Only collect libraries that need the over_react generated part.
    if (doesNotUseOverReact(sourceFile.getText(0))) {
      return;
    }

    // Recurse here so that the library and part of directives can be visited
    // (if present).
    super.visitCompilationUnit(node);

    // If no `part of` directive was visited, then this file is its own library.
    if (!_hasPartOfDirective) {
      _byPath.add(p.canonicalize(sourceFile.url.path));
    }
  }

  @override
  visitLibraryDirective(LibraryDirective node) {
    _byName.add(node.name.name);
  }

  @override
  visitPartOfDirective(PartOfDirective node) {
    _hasPartOfDirective = true;
    if (node.libraryName != null) {
      _byName.add(node.libraryName.name);
    } else if (node.uri != null) {
      _byPath.add(convertPartOfUriToRelativePath(
          sourceFile.url.path, Uri.parse(node.uri.stringValue)));
    }
  }
}
