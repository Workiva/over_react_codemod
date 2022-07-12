import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlMigrator extends ComponentUsageMigrator {
  final File _outputFile;
  final String _className;

  IntlMigrator(this._className, this._outputFile);

  @override
  String get fixmePrefix => 'FIXME - INTL ';
  @override
  bool get shouldFlagUnsafeMethodCalls => false;
  @override
  bool get shouldFlagUntypedSingleProp => false;
  @override
  bool get shouldFlagRefProp => false;
  @override
  bool get shouldFlagClassName => false;
  @override
  bool get shouldFlagExtensionMembers => false;
  @override
  bool get shouldFlagPrefixedProps => false;

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usage.cascadedProps.any((prop) =>
          isValidStringLiteralProp(prop) ||
          isValidStringInterpolationProp(prop)) ||
      usage.children.any((child) =>
          isValidStringLiteralNode(child.node) ||
          isValidStringInterpolationNode(child.node));

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    final namePrefix =
        usage.node.thisOrAncestorOfType<ClassDeclaration>()?.name.name ??
            usage.node.thisOrAncestorOfType<VariableDeclaration>()?.name.name ??
            'null';

    //Props
    final stringLiteralProps =
        usage.cascadedProps.where((prop) => isValidStringLiteralProp(prop));
    final stringInterpolationProps = usage.cascadedProps
        .where((prop) => isValidStringInterpolationProp(prop));

    stringLiteralProps.forEach((prop) => migratePropStringLiteral(prop));
    stringInterpolationProps.forEachIndexed((index, prop) =>
        migratePropStringInterpolation(prop, namePrefix, index));

    //Children
    final childNodes = usage.children.map((child) => child.node);
    //Migrate String Literals
    childNodes
        .whereType<SimpleStringLiteral>()
        .forEach((node) => migrateChildStringLiteral(node));

    //Migrate String Interpolations
    childNodes.whereType<StringInterpolation>().forEachIndexed((index, node) =>
        migrateChildStringInterpolation(node, namePrefix, index));
  }

  @override
  void flagCommon(FluentComponentUsage usage) {
    super.flagCommon(usage);
    // Flag the case of the label attribute, which may be user-visible or may not, depending
    // on the value of hideLabel.
    if (usage.builderType == null) return;
    if (!(usage.builderType!.isA('FormComponentDisplayPropsMixin'))) {
      return;
    }

    for (final prop in usage.cascadedProps) {
      var left = prop.leftHandSide;
      if (left is PropertyAccess && left.propertyName.toString() == 'label') {
        yieldBuilderMemberFixmePatch(prop,
            'The "label" property may or may not be user-visible, check hideLabel');
      }
    }
  }

  void migrateChildStringLiteral(
    SimpleStringLiteral node,
  ) {
    if (isValidStringLiteralNode(node)) {
      final functionCall = intlStringAccess(node, _className);
      final functionDef = intlGetterDef(node, _className);
      yieldPatchOverNode(functionCall, node);
      addMethodToClass(_outputFile, functionDef);
    }
  }

  void migrateChildStringInterpolation(
    StringInterpolation node,
    String namePrefix,
    int index,
  ) {
    if (isValidStringInterpolationNode(node)) {
      final functionCall =
          intlFunctionCall(node, _className, namePrefix, index);
      final functionDef = intlFunctionDef(node, _className, namePrefix, index);
      yieldPatchOverNode(functionCall, node);
      addMethodToClass(_outputFile, functionDef);
    }
  }

  void migratePropStringLiteral(
    PropAssignment prop,
  ) {
    if (isValidStringLiteralProp(prop)) {
      final rhs = prop.rightHandSide as SimpleStringLiteral;
      final functionCall = intlStringAccess(rhs, _className);
      final functionDef = intlGetterDef(rhs, _className);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_outputFile, functionDef);
    }
  }

  void migratePropStringInterpolation(
    PropAssignment prop,
    String namePrefix,
    int index,
  ) {
    if (isValidStringInterpolationProp(prop)) {
      final rhs = prop.rightHandSide as StringInterpolation;
      final functionCall = intlFunctionCall(rhs, _className, namePrefix, index);
      final functionDef = intlFunctionDef(rhs, _className, namePrefix, index);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_outputFile, functionDef);
    }
  }
}
