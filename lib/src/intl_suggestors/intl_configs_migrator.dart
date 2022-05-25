import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

const varsToCheck = ['displayName', 'name', 'title'];

class IntlConfigsMigrator extends RecursiveAstVisitor with AstVisitingSuggestor {
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if (varsToCheck.contains(node.name.name)) {
      if (node.body is ExpressionFunctionBody) {
        final body = (node.body as ExpressionFunctionBody).expression;
        if (body is SimpleStringLiteral) {
          if (body.value == '') return;
          final className = node.thisOrAncestorOfType<ClassDeclaration>()?.name;
          final name = node.name.name;
          final intl = intlMessageTemplate(body.stringValue!, '${className}_$name');
          yieldPatch(intl, body.offset, body.end);
        }
      }
    }
  }

  // @override
  // visitVariableDeclaration(VariableDeclaration node) {
  //   // TODO: implement visitVariableDeclaration
  //   super.visitVariableDeclaration(node);
  //   final rhs = node.initializer;
  //   if (rhs is SimpleStringLiteral) {
  //     final name = toVariableName(rhs.stringValue!);
  //     final intl = intlMessageTemplate(rhs.stringValue!, '${_namespace}_$name');
  //     yieldPatch(intl, rhs.offset, rhs.end);
  //   }
  // }

  @override
  bool shouldSkip(FileContext context) =>
      !context.path.contains('_config.dart');
}
