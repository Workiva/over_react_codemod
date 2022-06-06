import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

const varsToCheck = ['displayName', 'name', 'title'];

class ConfigsMigrator extends RecursiveAstVisitor with AstVisitingSuggestor {
  final String _className;
  final File _outputFile;

  ConfigsMigrator(this._className, this._outputFile);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if (varsToCheck.contains(node.name.name)) {
      if (node.body is ExpressionFunctionBody) {
        final body = (node.body as ExpressionFunctionBody).expression;
        if (body is SimpleStringLiteral) {
          if (body.value == '') return;
          final functionCall = intlStringAccess(body, _className);
          final functionDef = intlGetterDef(body, _className);
          yieldPatch(functionCall, body.offset, body.end);
          addMethodToClass(_outputFile, functionDef);
        }
      }
    }
  }

  @override
  bool shouldSkip(FileContext context) =>
      !context.path.contains('_config.dart');
}
