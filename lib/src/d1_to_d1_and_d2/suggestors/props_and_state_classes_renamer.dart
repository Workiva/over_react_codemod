import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../../constants.dart';
import '../util.dart';

/// Suggestor that renames all non-mixin props and state classes to have the
/// required `_$` prefix.
class PropsAndStateClassesRenamer extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    if (!node.metadata.any((m) =>
        overReactPropsStateNonMixinAnnotationNames.contains(m.name.name))) {
      // Only looking for classes annotated with `@Props()`, `@State()`,
      // `@AbstractProps()`, or `@AbstractState()`.
      return;
    }
    final className = node.name.name;
    final expectedName = renamePropsOrStateClass(className);
    if (className != expectedName) {
      yieldPatch(
        node.name.offset,
        node.name.end,
        expectedName,
      );
    }
  }
}
