
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

class IntlDeepMigrator extends RecursiveAstVisitor<Object> with AstVisitingSuggestor<Object> {
  /// The value returned for expressions (or non-expression nodes) that are not
  /// compile-time constant expressions.
  static Object? NOT_A_CONSTANT = Object();

  @override
  bool shouldResolveAst(FileContext context) => true;

  @override
  Object? visitSimpleStringLiteral(SimpleStringLiteral node) {
    super.visitSimpleStringLiteral(node);
    return node.value;
  }

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    // TODO: implement visitVariableDeclaration
    super.visitVariableDeclaration(node);
    final rhs = node.initializer;
    if (rhs is SimpleStringLiteral) {
      final name = toVariableName(rhs.stringValue!);
      final intl = intlMessageTemplate(rhs.stringValue!, '$name');
      yieldPatch(intl, rhs.offset, rhs.end);
    }
  }

  @override
  Object? visitStringInterpolation(StringInterpolation node) {
    super.visitStringInterpolation(node);
    final buffer = StringBuffer();
    for (final element in node.elements) {
      var value = element.accept(this);
      if (identical(value, NOT_A_CONSTANT)) {
        return value;
      }
      buffer.write(value);
    }
    return buffer.toString();
  }
}