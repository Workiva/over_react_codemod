import 'dart:math';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart' as collection;
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/ignore_info.dart';
import 'package:source_span/source_span.dart';

import 'class_suggestor.dart';

export 'class_suggestor.dart' show ClassSuggestor;
export 'wsd_util.dart';

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

  ShouldMigrateDecision shouldMigrateUsage(FluentComponentUsage usage);

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
        case ShouldMigrateDecision.no:
          break;
        case ShouldMigrateDecision.yes:
          migrateUsage(usage);
          break;
        case ShouldMigrateDecision.needsManualIntervention:
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
    String errorsMessage() => result.errors.isEmpty
        ? ''
        : ' \nAnalysis errors in file:\n${prettyPrintErrors(result.errors)}\n'
            'If this is a part file and all of its imported members seem to be unresolved,'
            ' make sure its library is resolved first.';
    final staticType = usage.builder.staticType;
    if (staticType == null || staticType.isDynamic) {
      final typeDescription = staticType == null
          ? 'null'
          : 'type \'${staticType.getDisplayString(withNullability: false)}\'';
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
  /// unsafe method calls (names not in [safeMethodCallNames] or [methodsWithCustomHandling])
  /// on component usages.
  bool get shouldFlagUnsafeMethodCalls => true;

  Set get methodsWithCustomHandling => const {'addProp'};

  Set get safeMethodCallNames => const {'addTestId'};

  bool get shouldFlagUntypedSingleProp => true;

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// static extension methods/accessors on component usages.
  bool get shouldFlagExtensionMembers => true;

  /// Whether [flagCommon] (called by [migrateUsage]) should flag
  /// prop prefixes (not in [safePropPrefixes])
  /// on component usages.
  bool get shouldFlagPrefixedProps => true;

  Set get safePropPrefixes => const {'dom', 'aria'};

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
            if (expression != null && !_isDataAttributePropKey(expression)) {
              yieldBuilderMemberFixmePatch(
                  method, '$name - manually verify prop key');
            }
            break;
        }
      } else if ((shouldFlagUnsafeMethodCalls &&
              !safeMethodCallNames.contains(name)) ||
          (shouldFlagExtensionMembers && method.node.isExtensionMethod)) {
        yieldBuilderMemberFixmePatch(method, '$name call - manually verify');
      }
    }

    for (final prop in usage.cascadedProps) {
      if (shouldFlagExtensionMembers && prop.isExtensionMethod) {
        // Flag extension methods, since they could do anything.
        yieldBuilderMemberFixmePatch(
            prop, '${prop.name.name} (extension) - manually verify');
      } else if (shouldFlagRefProp && prop.name.name == 'ref') {
        // Flag refs, since their type is likely to change.
        yieldPropFixmePatch(prop, 'manually verify ref type is correct');
      } else if (shouldFlagClassName && prop.name.name == 'className') {
        yieldPropFixmePatch(prop, 'manually verify');
      } else if (shouldFlagPrefixedProps &&
          prop.prefix != null &&
          !safePropPrefixes.contains(prop.prefix!.name)) {
        yieldBuilderMemberFixmePatch(
            prop, '${prop.prefix!.name} (prefix) - manually verify');
      }
    }

    for (final prop in usage.cascadedIndexAssignments) {
      if (!_isDataAttributePropKey(prop.index)) {
        yieldBuilderMemberFixmePatch(
            prop, 'operator[]= - manually verify prop key');
      }
    }

    for (final prop in usage.cascadedGetters) {
      if (shouldFlagExtensionMembers && prop.isExtensionMethod) {
        // Flag extension methods, since they could do anything.
        yieldBuilderMemberFixmePatch(
            prop, '${prop.name.name} (extension) - manually verify');
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
    yieldPatchOverNode('', prop.node);
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
      // Add spaces so that dartfmt has a better time in case the cascade section has leading line comments
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
    yieldBuilderMemberFixmePatch(prop, '${prop.name.name} prop - $message');
  }

  void yieldBuilderMemberFixmePatch(
      BuilderMemberAccess access, String message) {
    // Add an extra newline beforehand so that the comment doesn't end up on
    // the same line as the cascade target (the builder) in single-prop cascades.
    // Add a space so that dartfmt indents comment with the next line as opposed to
    // keeping it at the beginning of the line.
    // This formatting makes the output nicer, but more importantly it keeps
    // formatting of expected output in tests more consistent and easier to predict.
    final needsLeadingNewline = access.parentCascade != null &&
        context.sourceFile.getLine(access.parentCascade!.target.end) ==
            context.sourceFile.getLine(access.node.offset);
    yieldInsertionPatch(
        (needsLeadingNewline ? '\n ' : '') +
            lineComment('FIXME(mui_migration) - $message'),
        access.node.offset);
  }

  void yieldChildFixmePatch(ComponentChild child, String message) {
    // Add a leading newline so that, when children are all on the same line,
    // the comment doesn't get stuck to the previous child or invocation opening parens
    // Add a space so that dartfmt indents comment with the next line as opposed to
    // keeping it at the beginning of the line.
    // This formatting makes the output nicer, but more importantly it keeps
    // formatting of expected output in tests more consistent and easier to predict.
    final needsLeadingNewline = context.sourceFile.getLine(child.node.parent!
            .thisOrAncestorOfType<InvocationExpression>()!
            .argumentList
            .leftParenthesis
            .end) ==
        context.sourceFile.getLine(child.node.offset);
    yieldInsertionPatch(
        (needsLeadingNewline ? '\n ' : '') +
            lineComment('FIXME(mui_migration) - $message'),
        child.node.beginToken.offset);
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

enum ShouldMigrateDecision {
  /// A component usage should be migrated.
  yes,

  /// A component usage should not be migrated.
  no,

  /// A component usage should be migrated, but requires manual intervention
  /// and will get a fix-me comment but not any other automated migration logic.
  needsManualIntervention,
}

enum NewPropPlacement {
  auto,
  start,
  end,
}

void handleCascadedPropsByName(
  FluentComponentUsage usage,
  Map<String, void Function(PropAssignment)> propHandlersByName, {
  void Function(PropAssignment)? catchAll,
}) {
  // Validate that there aren't typos in they keys to `migratorsByName`.
  // This has negligible perf overhead and is extremely valuable when
  // authoring migrations.
  {
    final builderStaticType =
        usage.builder.staticType?.typeOrBounds.tryCast<InterfaceType>();
    if (builderStaticType != null) {
      final builderElement = builderStaticType.element;
      final builderClassName = builderElement.name;
      final library = usage.builder.root
          .tryCast<CompilationUnit>()
          ?.declaredElement!
          .library;
      if (library != null) {
        final unknownPropNames = propHandlersByName.keys
            .where((propName) =>
                builderElement.lookUpSetter(propName, library) == null)
            .toList();
        if (unknownPropNames.isNotEmpty) {
          throw ArgumentError(
              "'migratorsByName' contains unknown prop name(s) '$unknownPropNames'"
              " not statically available on builder class '$builderClassName'"
              " (declared in ${builderElement.enclosingElement.source.uri})."
              " Double-check that that prop exists in that props class"
              " and that the key in 'migratorsByName' does not have any typos.");
        }
      }
    }
  }

  for (final prop in usage.cascadedProps) {
    final handler = propHandlersByName[prop.name.name];
    if (handler != null) {
      handler(prop);
    } else if (catchAll != null) {
      catchAll(prop);
    }
  }
}

extension on SourceFile {
  /// Return the offset of the first character on the line following the line
  /// containing the given [offset].
  int getOffsetOfLineAfter(int offset) => getOffset(getLine(offset) + 1);
}

bool _isDataAttributePropKey(Expression expression) {
  final keyValue = _getStringConstantValue(expression);
  return keyValue != null && keyValue.startsWith('data-');
}

/// If the expression represents a constant string (e.g., a string literal
/// without interpolation, a reference to a string constant),
/// returns the value of that string, otherwise returns null.
///
/// This implementation may not be able to resolve all references, so a null
/// return value doesn't mean it's definitely not a string constant.
String? _getStringConstantValue(Expression expression) {
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
    final staticElement = node.staticElement ?? node.writeElement;
    return staticElement?.isExtensionMethod ?? false;
  }
}

extension on MethodInvocation {
  bool get isExtensionMethod =>
      methodName.staticElement?.isExtensionMethod ?? false;
}

// fixme implement
bool hasFlaggedComment(AstNode node) => false;

extension on DartType {
  DartType get typeOrBounds {
    final self = this;
    return self is TypeParameterType ? self.bound.typeOrBounds : self;
  }
}
