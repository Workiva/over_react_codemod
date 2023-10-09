import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

/// Migrate calls to addContextMenuItem, with either literals or interpolations.
class ContextMenuMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  final IntlMessages _messages;
  final String _className;

  ContextMenuMigrator(this._className, this._messages);

  @override
  visitMethodInvocation(MethodInvocation node) {
    migrateMenu(node);
    return super.visitMethodInvocation(node);
  }

  void migrateMenu(MethodInvocation node) {
    // We only care about calls to addContextMenuItem, with at least one
    // argument, we will migrate the first.
    var args = node.argumentList.arguments;
    if (args.isEmpty) return;
    if (node.methodName.name != 'addContextMenuItem') return;

    if (isValidStringLiteralNode(args.first)) {
      var literal = args.first as StringLiteral;
      final functionCall = _messages.syntax.getterCall(literal, _className);
      final functionDef =
          _messages.syntax.getterDefinition(literal, _className);
      yieldPatch(functionCall, literal.offset, literal.end);
      addMethodToClass(_messages, functionDef);
    }
    if (isValidStringInterpolationNode(args.first)) {
      var interpolation = args.first as StringInterpolation;
      final functionCall =
          _messages.syntax.functionCall(interpolation, _className, '');
      final functionDef =
          _messages.syntax.functionDefinition(interpolation, _className, '');
      // A lot of context menu calls are of the form 'Delete $type', which would be better done
      // as a fixed number of 'Delete Audit', 'Delete Form', etc. Add a comment to point that out.
      final callWithFixMe = '''
// FIXME - INTL Untranslated interpolated value. Is this one of a known set of possibilities?
$functionCall
''';
      yieldPatch(callWithFixMe, interpolation.offset, interpolation.end);
      addMethodToClass(_messages, functionDef);
    }
  }
}

class UsedMethodsChecker extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  final IntlMessages _messages;
  final String _className;

  UsedMethodsChecker(this._className, this._messages);

  @override
  visitPrefixedIdentifier(PrefixedIdentifier node) {
    if ('${node.prefix}' == _className) {
      _messages.noteUsage('${node.identifier}');
    }
    return super.visitPrefixedIdentifier(node);
  }

  @override
  visitMethodInvocation(MethodInvocation node) {
    if ('${node.target}' == _className) {
      _messages.noteUsage('${node.methodName}');
    }
    return super.visitMethodInvocation(node);
  }
}

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

  bool shouldMigrate(VariableDeclaration node) {
    if (isStatementIgnored(node)) return false;
    if (isFileIgnored(this.context.sourceText)) return false;
    return true;
  }

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    if (!shouldMigrate(node)) return;
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
      // If it looks like a CONSTANT_FROM_SOME_OTHER_LIBRARY don't convert it.
      if (string.toUpperCase() == string) return;
      // Is the first character uppercase, excluding strings that start with two of the same
      // uppercase character, which has a good chance of being a date format (e.g. 'MM/dd/YYYY').
      if (firstLetter != secondLetter &&
          firstLetter.toLowerCase() != firstLetter) {
        // Constant strings might be private.
        var name = publicNameFor(node);
        names.add(name);
        final functionCall =
            _messages.syntax.getterCall(literal, _className, name: name);
        final functionDef =
            _messages.syntax.getterDefinition(literal, _className, name: name);
        yieldPatch('final String ${node.name} = $functionCall', start, end);
        addMethodToClass(_messages, functionDef);
      }
    }
  }

  String publicNameFor(VariableDeclaration node) {
    var basicName = node.name.lexeme;
    // Make sure it's not private.
    var publicName =
        basicName.startsWith('_') ? basicName.substring(1) : basicName;
    if (isUnique(publicName)) {
      return publicName;
    } else {
      // Use a content-based name.
      var contentBasedName =
          toVariableName(stringContent(node.initializer as StringLiteral)!);
      return contentBasedName;
    }
  }

  bool isUnique(String name) => !names.contains(name);
}

class IntlMigrator extends ComponentUsageMigrator {
  final IntlMessages _messages;
  final String _className;

  IntlMigrator(this._className, this._messages);

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
  bool shouldMigrateUsage(FluentComponentUsage usage) {
    // TODO: Handle adjacent strings with an interpolation.
    if (isStatementIgnored(usage.node)) return false;
    if (isFileIgnored(this.context.sourceText)) return false;

    return usage.cascadedProps.any((prop) =>
            isValidStringLiteralProp(prop) ||
            isValidStringInterpolationProp(prop)) ||
        usage.children.any((child) =>
            isValidStringLiteralNode(child.node) ||
            isValidStringInterpolationNode(child.node));
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    final namePrefix = usage.node
            .thisOrAncestorOfType<ClassDeclaration>()
            ?.name
            .lexeme ??
        usage.node.thisOrAncestorOfType<VariableDeclaration>()?.name.lexeme ??
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
      final functionCall = _messages.syntax.getterCall(node, _className);
      final functionDef = _messages.syntax.getterDefinition(node, _className);
      yieldPatchOverNode(functionCall, node);
      addMethodToClass(_messages, functionDef);
    }
  }

  void migrateChildStringInterpolation(
      StringInterpolation node, String namePrefix) {
    if (isValidStringInterpolationNode(node)) {
      final functionCall =
          _messages.syntax.functionCall(node, _className, namePrefix);
      final functionDef =
          _messages.syntax.functionDefinition(node, _className, namePrefix);
      yieldPatchOverNode(functionCall, node);
      addMethodToClass(_messages, functionDef);
    }
  }

  void migratePropStringLiteral(
    PropAssignment prop,
  ) {
    if (isValidStringLiteralProp(prop)) {
      final rhs = prop.rightHandSide as StringLiteral;
      final functionCall = _messages.syntax.getterCall(rhs, _className);
      final functionDef = _messages.syntax.getterDefinition(rhs, _className);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_messages, functionDef);
    }
  }

  void migratePropStringInterpolation(
    PropAssignment prop,
    String namePrefix,
  ) {
    if (isValidStringInterpolationProp(prop)) {
      final rhs = prop.rightHandSide as StringInterpolation;
      final functionCall =
          _messages.syntax.functionCall(rhs, _className, namePrefix);
      final functionDef =
          _messages.syntax.functionDefinition(rhs, _className, namePrefix);
      yieldPropPatch(prop, newRhs: functionCall);
      addMethodToClass(_messages, functionDef);
    }
  }
}
