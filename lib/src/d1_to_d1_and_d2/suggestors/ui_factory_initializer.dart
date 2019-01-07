import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../../constants.dart';
import '../../util.dart';

class UiFactoryInitializer extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  static final RegExp factoryAnnotationPattern =
      RegExp(r'^@Factory\(', multiLine: true);

  static getFactoryInitializerValue(String factoryName) {
    if (factoryName.startsWith(privatePrefix)) {
      final factoryNameWithoutUnderscore =
          factoryName.substring(privatePrefix.length);
      return '$privateGeneratedPrefix$factoryNameWithoutUnderscore';
    }
    return '$generatedPrefix$factoryName';
  }

  @override
  bool shouldSkip(String sourceFileContents) =>
      !factoryAnnotationPattern.hasMatch(sourceFileContents);

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Look for a top-level variable that is annotated with @Factory()
    if (!node.metadata.any((annotation) => annotation.name.name == 'Factory')) {
      return;
    }

    // There can only be one UiFactory per file.
    final factoryNode = node?.variables?.variables?.first;
    if (factoryNode == null) {
      // TODO
      return;
    }

    final targetInitializer = getFactoryInitializerValue(factoryNode.name.name);
    final targetInitializerWithComment = [
      // Insert a line break to avoid the situation where a dartfmt run may
      // separate the ignore comment from the initializer value.
      '\n',
      '    ${buildIgnoreComment(undefinedIdentifier: true)}\n'
          '    $targetInitializer',
    ].join();

    final currentInitializer = factoryNode.initializer?.toSource()?.trim();
    if (currentInitializer == targetInitializer) {
      // Already initalized to the expected value.
      return;
    }

    if (factoryNode.initializer != null) {
      // Initializer exits, but does not match the expected value.
      yieldPatch(
        factoryNode.equals.end,
        factoryNode.initializer.end,
        targetInitializerWithComment,
      );
    } else {
      // Initializer does not yet exist.
      yieldPatch(
        factoryNode.name.end,
        factoryNode.end,
        ' =' + targetInitializerWithComment,
      );
    }
  }
}
