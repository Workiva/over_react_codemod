import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../../constants.dart';
import '../../util.dart';

class PropsAndStateMixinMetaAdder extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  bool _hasStaticMetaField;

  @override
  visitClassDeclaration(ClassDeclaration node) {
    // Reset this flag, as it is specific to each source file/compilation unit.
    _hasStaticMetaField = false;

    // Only looking for @PropsMixin() and @StateMixin() classes.
    String metaType;
    final isOverReactMixin = node.metadata.any((annotation) {
      if (overReactMixinAnnotationNames.contains(annotation.name.name)) {
        metaType =
            annotation.name.name.contains('Props') ? 'PropsMeta' : 'StateMeta';
        return true;
      }
      return false;
    });
    if (!isOverReactMixin) {
      return;
    }

    // Recurse here so that the class fields are visited.
    super.visitClassDeclaration(node);

    if (_hasStaticMetaField) {
      return;
    }

    final ignoreComment = buildIgnoreComment(
      constInitializedWithNonConstantValue: true,
      undefinedClass: true,
      undefinedIdentifier: true,
    );
    yieldPatch(
      node.leftBracket.end,
      node.leftBracket.end,
      [
        '',
        '  $ignoreComment',
        '  static const $metaType meta = \$metaFor${node.name.name};',
        '',
      ].join('\n'),
    );
  }
}
