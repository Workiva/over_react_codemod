import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

/// Mark const string variables whose first character is uppercase for internationalization. e.g.
///
///   const String cancel = 'Cancel';
///
/// Turns it into
///
///   final String cancel = <IntlClassName>.cancel;
class ConstantStringMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  final IntlMessages _messages;
  final String _className;
  Set<String> names = {};

  ConstantStringMigrator(this._className, this._messages);

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    // We expect it to be const and have an initializer that's a simple string.
    if (node.isConst &&
        node.initializer != null &&
        node.initializer is SimpleStringLiteral) {
      SimpleStringLiteral literal = node.initializer as SimpleStringLiteral;
      var string = literal.stringValue;
      // I don't see how the parent could possibly be null, but if it's true, bail out.
      if (node.parent == null || string == null || string.length <= 1) return;
      // Otherwise use the parent to find the area to replace, because we want to replace
      // the full declaration. Re-assure the compiler that we're positive it's not null.
      var start = node.parent!.offset;
      var end = node.parent!.end;
      var firstLetter = string.substring(0, 1);
      var secondLetter = string.substring(1, 2);
      // Is the first character uppercase, excluding strings that start with two of the same
      // uppercase character, which has a good chance of being a date format (e.g. 'MM/dd/YYYY').
      if (firstLetter != secondLetter &&
          firstLetter.toLowerCase() != firstLetter) {
        // Constant strings might be private.
        var name = publicNameFor(node);
        names.add(name);
        final functionCall = intlStringAccess(literal, _className, name: name);
        final functionDef = intlGetterDef(literal, _className, name: name);
        yieldPatch('final String ${node.name} = $functionCall', start, end);
        addMethodToClass(_messages, functionDef);
      }
    }
  }

  String publicNameFor(VariableDeclaration node) {
    var basicName = node.name.name;
    // Make sure it's not private.
    var publicName =
        basicName.startsWith('_') ? basicName.substring(1) : basicName;
    if (isUnique(publicName)) return publicName;
    var contentBasedName =
        toVariableName(stringContent(node.initializer as StringLiteral)!);
    if (isUnique(contentBasedName)) return contentBasedName;
    return appendANumberTo(publicName);
  }

  bool isUnique(String name) => !names.contains(name);

  /// Make a name that's unique within the constant methods in the Intl file.
  ///
  /// Do this by appending a number. It recursively tries each number in turn, which
  /// would be pretty inefficient for large numbers, but if we have even dozens of duplicate
  /// names then we need to change our approach more than just making unique numbers faster.
  String appendANumberTo(String name, [int counter = 1]) {
    // TODO: This is only unique within constants. It would be better to move this
    // into a class representing the output.
    if (!names.contains(name)) {
      return name;
    } else if (!names.contains('$name$counter')) {
      return '$name$counter';
    } else {
      return appendANumberTo(name, counter + 1);
    }
  }
}

class IntlMigrator extends ComponentUsageMigrator {
  final IntlMessages _outputFile;
  final String _className;

  int functionIndex = 0;
  int nextFunctionIndex() => functionIndex++;

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
      // TODO: Handle adjacent strings with an interpolation.
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

    stringLiteralProps.forEach(migratePropStringLiteral);
    stringInterpolationProps
        .forEach((prop) => migratePropStringInterpolation(prop, namePrefix));

    //Children
    final childNodes = usage.children.map((child) => child.node).toList();
    //Migrate String Literals
    childNodes
        .whereType<StringLiteral>()
        .forEach((node) => migrateChildStringLiteral(node));

    //Migrate String Interpolations
    childNodes
        .whereType<StringInterpolation>()
        .forEach((node) => migrateChildStringInterpolation(node, namePrefix));
  }

  @override
  void flagCommon(FluentComponentUsage usage) {
    super.flagCommon(usage);
    // Flag the case of the label attribute, which may be user-visible or may not, depending
    // on the value of hideLabel.

    // This is commented out, because it turns out we should be internationalizing the
    // label attribute, even if hideLabel is true, because it is visible to screen readers.
    // Leaving the code here in case it's useful as an example for other properties we may
    // need to customize.

    // if (usage.builderType == null) return;
    // if (!(usage.builderType!.isOrIsSubtypeOfClassFromPackage(
    //     'FormComponentDisplayPropsMixin', 'web_skin_dart'))) {
    //   return;
    // }

    // for (final prop in usage.cascadedProps) {
    //   var left = prop.leftHandSide;
    //   if (left is PropertyAccess && left.propertyName.toString() == 'label') {
    //     yieldBuilderMemberFixmePatch(prop,
    //         'The "label" property may or may not be user-visible, check hideLabel');
    //   }
    // }
  }

  void migrateChildStringLiteral(
    StringLiteral node,
  ) {
    if (isValidStringLiteralNode(node)) {
      final functionCall = intlStringAccess(node, _className);
      final functionDef = intlGetterDef(node, _className);
      yieldPatchOverNode(functionCall, node);
      addMethodToClass(_outputFile, functionDef);
    }
  }

  void migrateChildStringInterpolation(
      StringInterpolation node, String namePrefix) {
    if (isValidStringInterpolationNode(node)) {
      var index = nextFunctionIndex();
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
      final rhs = prop.rightHandSide as StringLiteral;
      final functionCall = intlStringAccess(rhs, _className);
      final functionDef = intlGetterDef(rhs, _className);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_outputFile, functionDef);
    }
  }

  void migratePropStringInterpolation(
    PropAssignment prop,
    String namePrefix,
  ) {
    if (isValidStringInterpolationProp(prop)) {
      final rhs = prop.rightHandSide as StringInterpolation;
      final index = nextFunctionIndex();
      final functionCall = intlFunctionCall(rhs, _className, namePrefix, index);
      final functionDef = intlFunctionDef(rhs, _className, namePrefix, index);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_outputFile, functionDef);
    }
  }
}
