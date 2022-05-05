import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

class ExperienceDisplayNameMigrator extends RecursiveAstVisitor with AstVisitingSuggestor {
  final String _className;
  final File _outputFile;

  ExperienceDisplayNameMigrator(this._className, this._outputFile);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name == 'displayName') {
      final body = (node.body as ExpressionFunctionBody).expression;
      if (body is SimpleStringLiteral) {
        if (body.value == '') return;
        final name = toVariableName(body.value);
        yieldPatch('${_className}.$name', body.offset, body.end);
        addMethodToClass(_outputFile, literalTemplate(_className, name, body.value));
      }
    }
  }

  @override
  bool shouldSkip(FileContext context) =>
      !context.path.contains('experience');
}
