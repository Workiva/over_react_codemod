import 'dart:math';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart' as collection;
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/element_type_helpers.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/ignore_info.dart';
import 'package:source_span/source_span.dart';

import 'class_suggestor.dart';
export 'class_suggestor.dart' show ClassSuggestor;

final isValidSimpleIdentifier = RegExp(r'[_$a-zA-Z][_$a-zA-Z0-9]*').hasMatch;

/// Component usages can be ignored via comments, resulting in this migrator
/// not calling [shouldMigrateUsage]/[migrateUsage] for them.
///
/// Comment formats:
///
/// - An `// orcm_ignore` comment on the first line of the usage or the line before it:
///
///     ```dart
///     // orcm_ignore
///     Foo()();
///
///     (Foo() // orcm_ignore
///       ..bar = baz
///     )()
///     ```
///
/// - An `// orcm_ignore_for_file` comment, which ignores everything in the file.
///
///     ```dart
///     // orcm_ignore_for_file
///
///     // All of the following usages get ignored:
///     Foo()();
///     Bar()();
///     ```
///
/// - An `// orcm_ignore_for_file: ` comment with one or more factory or props class
///   names, separated by commas:
///
///     ```dart
///     // orcm_ignore_for_file: Foo, BarProps
///
///     BuilderOnlyUiFactory<BarProps> barFactory;
///
///     // All of the following usages get ignored:
///     Foo()();
///     Bar()();
///     barFactory()();
///     ```
mixin ComponentUsageMigrator on ClassSuggestor {
  static final _log = Logger('ComponentUsageMigrator');

  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage);

  @mustCallSuper
  void migrateUsage(FluentComponentUsage usage) {
    flagCommon(usage);
  }

  bool get ignoreAlreadyFlaggedUsages => true;

  static const _fatalUnresolvedUsages = true;

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    // fixme codemod apparently you have to resolve the main library before resolving a part??

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    final unit = result.unit;
    if (unit == null) {
      throw Exception(
          'Could not get resolved unit for "${context.relativePath}"');
    }

    final allUsages = <FluentComponentUsage>[];
    unit.accept(ComponentUsageVisitor(allUsages.add));

    for (final usage in allUsages) {
      if (_isIgnored(usage, unit)) {
        _log.finest(context.sourceFile
            .spanFor(usage.factoryOrBuilder)
            .message('Skipping ignored usage'));
        continue;
      }

      if (ignoreAlreadyFlaggedUsages && hasFlaggedComment(usage.node)) {
        continue;
      }

      // If things aren't fully resolved, the unresolved branch of the FluentComponentUsage
      // detection will be used. Check for that here, since that probably means
      // the library declaring the component wasn't resolved, and we want to know
      // about it so the component isn't skipped over silently (since the checks
      // to see what component it is often rely on resolved AST).
      if (_fatalUnresolvedUsages) {
        verifyUsageIsResolved(usage, result);
      }

      final decision = shouldMigrateUsage(usage);
      switch (decision) {
        case MigrationDecision.notApplicable:
          break;
        case MigrationDecision.shouldMigrate:
          migrateUsage(usage);
          break;
        case MigrationDecision.needsManualIntervention:
          flagUsageWithManualIntervention(usage);
          break;
      }
    }
  }

  Exception _unresolvedException(String message, SyntacticEntity entity) {
    const commonMessage =
        'Check that `pub get` has been run and that this is a valid over_react component usage.';
    final span = context.sourceFile.span(entity.offset, entity.end);
    return Exception(span.message('$message$commonMessage'));
  }

  void verifyUsageIsResolved(
      FluentComponentUsage usage, ResolvedUnitResult result) {
    // fixme add note in error message about part file needing to be resolved after main library

    String errorsMessage() => result.errors.isEmpty
        ? ''
        : ' \nAnalysis errors in file:\n${prettyPrintErrors(result.errors)}\n';
    //error: Undefined name 'message'. (undefined_identifier at [over_react_codemod] lib/src/util/component_usage_migrator.dart:228)
    final staticType = usage.builder.staticType;
    if (staticType == null || staticType.isDynamic) {
      final typeDescription = staticType == null
          ? 'null'
          : 'type \'${staticType.getDisplayString(withNullability: false)}\'';
      // debugger();
      throw _unresolvedException(
          'Builder static type could not be resolved; was $typeDescription. ${errorsMessage()}',
          usage.builder);
    }
    final factory = usage.factory;
    if (factory != null) {
      if (factory.staticType == null ||
          (factory is Identifier && factory.staticElement == null)) {
        throw _unresolvedException(
            'Factory could not be resolved. ${errorsMessage()}', factory);
      }
    }
  }

  //
  // Common migration flagging

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// unsafe method calls (names not in [safeMethodCallNames] or [_methodsWithCustomHandling])
  ///on component usages.
  bool get shouldFlagUnsafeMethodCalls => true;

  Set get methodsWithCustomHandling => const {'addProp'};

  Set get safeMethodCallNames => const {'addTestId'};

  bool get shouldFlagUntypedSingleProp => true;

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// static extension methods/accessors on component usages.
  bool get shouldFlagExtensionMembers => true;

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// the `ref` prop component usages.
  bool get shouldFlagRefProp => true;

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// the `className` prop on component usages.
  // FIXME CPLAT-15321 also flag WS classes in custom CSS selectors
  bool get shouldFlagClassName => true;

  void flagCommon(FluentComponentUsage usage) {
    // Flag things like addProps, addAll, modifyProps, which could be adding
    // props for the old component.
    // This also handles extension methods.
    for (final method in usage.cascadedMethodInvocations) {
      final name = method.methodName.name;

      if (methodsWithCustomHandling.contains(name)) {
        switch (name) {
          case 'addProp':
            final expression = method.node.argumentList.arguments.firstOrNull;
            if (expression != null && !isDataAttributePropKey(expression)) {
              yieldPatch(
                  lineComment(
                      'FIXME(mui_migration) - ${name} - manually verify prop key'),
                  method.node.offset,
                  method.node.offset);
            }
            break;
        }
      } else if ((shouldFlagUnsafeMethodCalls &&
              !safeMethodCallNames.contains(name)) ||
          (shouldFlagExtensionMembers && method.node.isExtensionMethod)) {
        yieldInsertionPatch(
            lineComment(
                'FIXME(mui_migration) - ${name} call - manually verify'),
            method.node.offset);
      }
    }

    for (final prop in usage.cascadedProps) {
      if (shouldFlagExtensionMembers && prop.isExtensionMethod) {
        // Flag extension methods, since they could do anything.
        yieldInsertionPatch(
            lineComment(
                'FIXME(mui_migration) - ${prop.name.name} (extension) - manually verify'),
            prop.assignment.offset);
      } else if (shouldFlagRefProp && prop.name.name == 'ref') {
        // Flag refs, since their type is likely to change.
        yieldInsertionPatch(
            lineComment(
                'FIXME(mui_migration) - ref - manually verify ref type is correct'),
            prop.assignment.offset);
      } else if (shouldFlagClassName && prop.name.name == 'className') {
        yieldInsertionPatch(
            lineComment('FIXME(mui_migration) - className - manually verify'),
            prop.assignment.offset);
      }
    }

    for (final prop in usage.cascadedIndexAssignments) {
      if (!isDataAttributePropKey(prop.index)) {
        yieldInsertionPatch(
            lineComment(
                'FIXME(mui_migration) - operator[]= - manually verify prop key'),
            prop.node.offset);
      }
    }

    for (final prop in usage.cascadedGetters) {
      if (shouldFlagExtensionMembers && prop.isExtensionMethod) {
        // Flag extension methods, since they could do anything.
        yieldInsertionPatch(
            lineComment(
                'FIXME(mui_migration) - ${prop.name.name} (extension) - manually verify'),
            prop.node.offset);
      }
    }
  }

  //
  // Helpers

  static const _manualInterventionMessage = 'needs manual intervention';

  void flagUsageWithManualIntervention(FluentComponentUsage usage) {
    flagUsageFixmeComment(usage, _manualInterventionMessage);
  }

  void flagUsageFixmeComment(FluentComponentUsage usage, String message) {
    yieldInsertionPatch(
        lineComment('FIXME(mui_migration) $message'), usage.node.offset);
  }

  void yieldPatchOverNode(String updatedText, SyntacticEntity entityToReplace) {
    yieldPatch(updatedText, entityToReplace.offset, entityToReplace.end);
  }

  void yieldRemovePropPatch(PropAssignment prop) {
    yieldPatchOverNode('', prop.assignment);
  }

  void yieldAddPropPatch(FluentComponentUsage usage, String newPropCascade,
      {NewPropPlacement placement = NewPropPlacement.auto}) {
    final function = usage.node.function;
    if (function is ParenthesizedExpression) {
      // If this is null, we default to right after the invocation.
      final int offset;
      switch (placement) {
        case NewPropPlacement.auto:
          // Try to insert it after other props that aren't method calls or index expressions,
          // or members typically inserted at the end like addTestId, key, and ref.
          final propToInsertAfter =
              usage.cascadedMembers.lastWhereOrNull((element) {
            if (element is BuilderMethodInvocation) {
              return false;
            } else if (element is PropAssignment) {
              final name = element.name.name;
              return name != 'key' && name != 'ref';
            } else if (element is IndexPropAssignment) {
              return false;
            } else {
              throw ArgumentError.value(
                  element, 'element', 'Unhandled BuilderMemberAccess subtype');
            }
          });
          // Insert at the beginning of the next line so that we're not fighting with
          // insertions at the beginning of that prop (e.g., fix-me comments).
          offset = propToInsertAfter != null
              ? min(
                  context.sourceFile
                      .getOffsetOfLineAfter(propToInsertAfter.node.end),
                  // Ensure this position isn't outside of the cascade parens
                  // (e.g., single-line cascade, multiline cascade with non-aligned right paren).
                  function.rightParenthesis.offset,
                )
              : function.rightParenthesis.offset;
          break;
        case NewPropPlacement.start:
          // TODO would it be better formatting and insertion-wise to attempt to insert at the beginning of the line of the first prop (similar to above)?
          offset = usage.cascadeExpression?.target.end ??
              function.rightParenthesis.offset;
          break;
        case NewPropPlacement.end:
          // TODO would it be better formatting and insertion-wise to attempt to insert at the beginning of the line after the last prop (similar to above)?
          offset = function.rightParenthesis.offset;
          break;
      }
      yieldInsertionPatch('\n' + newPropCascade, offset);
    } else {
      assert(usage.cascadeExpression == null);

      yieldInsertionPatch('(', function.offset);
      yieldInsertionPatch(newPropCascade, function.end);
      // Separate the closing paren and the cascade patches so that they can be
      // applied separately if there are other calls to addProp.
      yieldInsertionPatch(')', function.end);
    }
  }

  void yieldRemoveChildPatch(AstNode child) {
    // This logic is a little extra, but isn't too much effort and helps keep things tidy.

    final int start;
    final int end;

    // If there's a trailing comma, remove it with the child
    final nextToken = child.endToken.next;
    if (nextToken != null && nextToken.type == TokenType.COMMA) {
      start = child.offset;
      end = nextToken.end;
    } else {
      // Otherwise, if there's a comma before the child, remove that
      // so that the list doesn't go from not having trailing commas to having them.
      final prevToken = child.beginToken.previous;
      if (prevToken != null && prevToken.type == TokenType.COMMA) {
        start = prevToken.offset;
        end = child.end;
      } else {
        // Otherwise, we're probably a single child. Just remove the child itself.
        start = child.offset;
        end = child.end;
      }
    }
    yieldPatch('', start, end);
  }

  void yieldPropPatch(
    PropAssignment prop, {
    String? newName,
    String? newRhs,
    String? additionalCascadeSection,
  }) {
    if (newName == null && newRhs == null) {
      throw ArgumentError.notNull('either newName or newRhs');
    }

    if (newName != null) {
      yieldPatchOverNode(newName, prop.name);
    }

    if (newRhs != null) {
      yieldPatchOverNode(newRhs, prop.rightHandSide);
    }

    if (additionalCascadeSection != null) {
      // Add spaces so that dartfmt has a better time // todo is this necessary?
      yieldInsertionPatch(
          '\n  $additionalCascadeSection', prop.rightHandSide.end);
    }
  }

  // fixme clean up comment
  // Unhandled cases need to be manually addressed; flag them as such.
  //
  // While we could handle more cases in the codemod (e.g., ternaries)
  // it's not worth the additional effort since they're so uncommon.
  //
  // And while, for some cases, it will be be obvious that they need to be manually addressed
  // since they'll result in analysis errors (e.g., variables, method calls that reference a ButtonSkin),
  // some cases (e.g., expressions with type `dynamic`) will NOT cause analysis errors
  // and will need to be checked manually.
  void yieldPropManualVerificationPatch(PropAssignment prop) {
    yieldPropFixmePatch(prop, 'manually verify');
  }

  void yieldPropManualMigratePatch(PropAssignment prop) {
    yieldPropFixmePatch(prop, 'manually migrate');
  }

  void yieldPropFixmePatch(PropAssignment prop, String message) {
    yieldInsertionPatch(
        lineComment('FIXME(mui_migration) - ${prop.name.name} prop - $message'),
        prop.assignment.offset);
  }

  static final _ignoreInfoForUnitCache = Expando<OrcmIgnoreInfo>();

  /// Returns whether a [usage] has been ignored via a comment.
  ///
  /// See [ComponentUsageMigrator] for comment formats.
  bool _isIgnored(FluentComponentUsage usage, CompilationUnit unit) {
    final ignoreInfo = _ignoreInfoForUnitCache[unit] ??=
        OrcmIgnoreInfo.forDart(unit, context.sourceText);
    // IgnoreInfo's line numbers are 1-based,
    // whereas SourceFile's are 0-based
    final line = context.sourceFile.getLine(usage.node.offset) + 1;

    if (ignoreInfo.blanketIgnoredAt(line)) {
      return true;
    }

    final componentName = usage.componentName;
    final propsName = usage.propsName;
    final codes = <String>[
      if (componentName != null) componentName,
      if (propsName != null) propsName,
    ];
    return codes.any((code) => ignoreInfo.ignoredAt(code, line));
  }
}

void migratePropsByName(
  FluentComponentUsage usage, {
  required Map<String, void Function(PropAssignment)> migratorsByName,
  void Function(PropAssignment)? catchAll,
}) {
  // Validate that there aren't typos in they keys to `migratorsByName`.
  // This has negligible perf overhead and is extremely valuable when
  // authoring migrations.
  {
    final builderStaticType =
        usage.builder.staticType?.typeOrBounds as InterfaceType?;
    if (builderStaticType != null) {
      final builderElement = builderStaticType.element;
      final builderClassName = builderElement.name;
      final library =
          (usage.builder.root as CompilationUnit).declaredElement!.library;
      final unknownPropNames = migratorsByName.keys
          .where((propName) =>
              builderElement.lookUpSetter(propName, library) == null)
          .toList();
      if (unknownPropNames.isNotEmpty) {
        throw ArgumentError(
            "'migratorsByName' contains unknown prop name(s) '$unknownPropNames'"
            " not statically available on builder class '$builderClassName'"
            " (declared in ${builderElement.enclosingElement.uri})."
            " Double-check that that prop exists in that props class"
            " and that the key in 'migratorsByName' does not have any typos.");
      }
    }
  }

  for (final prop in usage.cascadedProps) {
    final propMigrator = migratorsByName[prop.name.name];
    if (propMigrator != null) {
      propMigrator(prop);
    } else if (catchAll != null) {
      catchAll(prop);
    }
  }
}

extension on SourceFile {
  FileSpan spanFor(SyntacticEntity entity) => span(entity.offset, entity.end);
}

enum NewPropPlacement {
  auto,
  start,
  end,
}

extension on SourceFile {
  /// Return the offset of the first character on the line following the line
  /// containing the given [offset].
  int getOffsetOfLineAfter(int offset) => getOffset(getLine(offset) + 1);
}

bool isDataAttributePropKey(Expression expression) {
  final keyValue = getStringConstantValue(expression);
  return keyValue != null && keyValue.startsWith('data-');
}

/// If the expression represents a constant string (e.g., a string literal
/// without interpolation, a reference to a string constant),
/// returns the value of that string, otherwise returns null.
///
/// This implementation may not be able to resolve all references, so a null
/// return value doesn't mean it's definitely not a string constant.
String? getStringConstantValue(Expression expression) {
  if (expression is SimpleStringLiteral) {
    return expression.value;
  }

  Element? staticElement;
  if (expression is Identifier) {
    staticElement = expression.staticElement;
  } else if (expression is PropertyAccess) {
    staticElement = expression.propertyName.staticElement;
  }

  if (staticElement != null) {
    VariableElement? variable;
    if (staticElement is VariableElement) {
      variable = staticElement;
    } else if (staticElement is PropertyAccessorElement) {
      variable = staticElement.variable;
    }

    if (variable != null && variable.isConst) {
      return variable.computeConstantValue()?.toStringValue();
    }
  }

  return null;
}

extension on Element {
  bool get isExtensionMethod {
    final self = this;
    return enclosingElement is ExtensionElement &&
        self is ExecutableElement &&
        !self.isStatic;
  }
}

extension on PropAccess {
  bool get isExtensionMethod {
    final staticElement = node.propertyName.staticElement;
    return staticElement?.isExtensionMethod ?? false;
  }
}

extension on PropAssignment {
  bool get isExtensionMethod {
    // For some reason staticElement on extensions is null, and we need to use
    // writeElement instead. TODO report this as an analyzer bug?
    final staticElement = assignment.staticElement ?? assignment.writeElement;
    return staticElement?.isExtensionMethod ?? false;
  }
}

extension on MethodInvocation {
  bool get isExtensionMethod =>
      methodName.staticElement?.isExtensionMethod ?? false;
}

enum MigrationDecision {
  shouldMigrate,
  needsManualIntervention,
  notApplicable,
}

extension FileContextSourceHelper on FileContext {
  String sourceFor(SyntacticEntity entity) =>
      sourceText.substring(entity.offset, entity.end);
}

// todo properly escape
String blockComment(String contents) => '/*$contents*/';

String lineComment(String contents) =>
    contents.split('\n').map((line) => '// $line\n').join('');

// fixme implement
bool hasFlaggedComment(AstNode node) => false;

extension on DartType {
  DartType get typeOrBounds {
    final self = this;
    return self is TypeParameterType ? self.bound.typeOrBounds : self;
  }
}

V? mapWsdConstant<V>(
    Expression expression, Map<String, V> wsdConstantToNewValue) {
  return wsdConstantToNewValue.entries
      .where((element) => isWsdStaticConstant(expression, element.key))
      .map((e) => e.value)
      .firstOrNull;
}

bool isWsdStaticConstant(Expression expression, String constant,
        {String? fromPackage}) =>
    isStaticConstant(expression, constant, fromPackage: 'web_skin_dart');

bool isStaticConstant(Expression expression, String constant,
    {String? fromPackage}) {
  final constantParts = constant.split('.');
  if (constantParts.length != 2) {
    throw ArgumentError.value(
        constant, 'constant', "Expected 'ClassName.constantName'");
  }

  final className = constantParts[0];
  final staticFieldName = constantParts[1];

  // FIXME handle more cases (namespaced, etc)
  // fixme check is static

  Element? staticElement;
  if (expression is PropertyAccess && !expression.isCascaded) {
    staticElement = expression.propertyName.staticElement;
  } else if (expression is PrefixedIdentifier) {
    staticElement = expression.identifier.staticElement;
  }
  if (staticElement == null) return false;

  return staticElement.name == staticFieldName &&
      staticElement.enclosingElement?.name == className &&
      (fromPackage == null || staticElement.isDeclaredInPackage(fromPackage));
}

bool usesWsdFactory(FluentComponentUsage usage, String wsdFactoryName) {
  if (!isValidSimpleIdentifier(wsdFactoryName)) {
    throw ArgumentError.value(wsdFactoryName, 'wsdFactoryName',
        'must be a valid, non-namespaced identifier');
  }

  final factoryStaticElement =
      usage.factory?.tryCast<Identifier>()?.staticElement;
  if (factoryStaticElement == null) return false;

  return factoryStaticElement.name == wsdFactoryName &&
      factoryStaticElement.isDeclaredInWsd;
}

bool usesWsdV1Factory(FluentComponentUsage usage) {
  final factoryStaticElement =
      usage.factory?.tryCast<Identifier>()?.staticElement;
  if (factoryStaticElement == null || !factoryStaticElement.isDeclaredInWsd) {
    return false;
  }

  final declaringFileName =
      factoryStaticElement.thisOrAncestorOfType<CompilationUnitElement>()?.uri;

  return declaringFileName != null &&
      declaringFileName.contains('/src/_deprecated/');
}
