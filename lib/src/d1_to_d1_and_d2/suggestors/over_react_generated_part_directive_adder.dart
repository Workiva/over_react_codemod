import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:path/path.dart' as p;

import '../../constants.dart';
import '../../util.dart';
import 'needs_over_react_library_collector.dart';

class OverReactGeneratedPartDirectiveAdder extends SimpleAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final NeedsOverReactLibraryCollector _libraryCollector;

  OverReactGeneratedPartDirectiveAdder(this._libraryCollector);

  @override
  visitCompilationUnit(CompilationUnit node) {
    bool needsGeneratedPartDirective = false;

    final canonicalizedPath = p.canonicalize(sourceFile.url.path);
    if (_libraryCollector.byPath.contains(canonicalizedPath)) {
      needsGeneratedPartDirective = true;
    }

    for (final member in node.sortedDirectivesAndDeclarations) {
      if (member is LibraryDirective) {
        if (member.name != null &&
            _libraryCollector.byName.contains(member.name.name)) {
          needsGeneratedPartDirective = true;
          break;
        }
      }
    }

    if (!needsGeneratedPartDirective) {
      return;
    }

    final generatedPartUri = p.setExtension(
      p.basename(sourceFile.url.path),
      overReactGeneratedExtension,
    );
    Directive lastDirective;
    for (final member in node.sortedDirectivesAndDeclarations) {
      if (member is Directive) {
        lastDirective = member;
      }
      if (member is PartDirective) {
        if (member.uri.stringValue == generatedPartUri) {
          return;
        }
      }
    }

    final ignoreComment = buildIgnoreComment(uriHasNotBeenGenerated: true);
    yieldPatch(
      lastDirective.end,
      lastDirective.end,
      "\n$ignoreComment\npart '$generatedPartUri';",
    );
  }
}
