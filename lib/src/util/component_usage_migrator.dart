import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/element_type_helpers.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

mixin ClassSuggestor {
  final _patches = <Patch>{};

  /// The context helper for the file currently being visited.
  FileContext get context {
    if (_context != null) return _context!;
    throw StateError('context accessed outside of a visiting context. '
        'Ensure that your suggestor only accesses `this.context` inside an AST visitor method.');
  }

  FileContext? _context;

  Stream<Patch> call(FileContext context) async* {
    if (shouldSkip(context)) return;

    _patches.clear();
    _context = context;

    await generatePatches();

    // Force the copying of this list, otherwise it would be a lazy iterable
    // mapped to the field on this class that will change on the next call.
    final patches = _patches.toList();
    _context = null;

    yield* Stream.fromIterable(patches);
  }

  Future<void> generatePatches();

  /// Whether the file represented by [context] should be parsed and visited.
  ///
  /// Subclasses can override this to skip all work for a file based on its
  /// contents if needed.
  bool shouldSkip(FileContext context) => false;

  void yieldPatch(String updatedText, int startOffset, [int? endOffset]) {
    _patches.add(Patch(updatedText, startOffset, endOffset));
  }
}

mixin ComponentUsageMigrator on ClassSuggestor {
  static final _log = Logger('ComponentUsageMigrator');

  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage);

  @mustCallSuper
  void migrateUsage(FluentComponentUsage usage) {
    flagCommon(usage);
  }

  bool get ignoreAlreadyFlaggedUsages => true;

  bool usesWsdFactory(FluentComponentUsage usage, String wsdFactoryName) {
    final factoryStaticElement =
        usage.factory?.tryCast<Identifier>()?.staticElement;
    if (factoryStaticElement == null) return false;

    return factoryStaticElement.name == wsdFactoryName &&
        factoryStaticElement.isDeclaredInWsd;
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');
    final result = await context.getResolvedUnit();
    final unit = result?.unit;
    if (unit == null) {
      _log.warning('Could not get resolved unit for "${context.relativePath}"');
      return;
    }

    final allUsages = <FluentComponentUsage>[];
    unit.accept(ComponentUsageVisitor(allUsages.add));

    for (final usage in allUsages) {
      if (ignoreAlreadyFlaggedUsages && hasFlaggedComment(usage.node)) {
        continue;
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
            final expression = method.argumentList.arguments.firstOrNull;
            if (expression != null && !isDataAttributePropKey(expression)) {
              yieldPatch(
                  lineComment(
                      'FIXME(mui_migration) - ${name} addProp - manually verify prop key'),
                  method.offset,
                  method.offset);
            }
            break;
        }
      } else if ((shouldFlagUnsafeMethodCalls &&
              !safeMethodCallNames.contains(name)) ||
          (shouldFlagExtensionMembers && method.isExtensionMethod)) {
        yieldPatch(
            lineComment(
                'FIXME(mui_migration) - ${name} call - manually verify'),
            method.offset,
            method.offset);
      }
    }

    for (final prop in usage.cascadedProps) {
      if (shouldFlagExtensionMembers && prop.isExtensionMethod) {
        // Flag extension methods, since they could do anything.
        yieldPatch(
            lineComment(
                'FIXME(mui_migration) - ${prop.name.name} (extension) - manually verify'),
            prop.assignment.offset,
            prop.assignment.offset);
      } else if (shouldFlagRefProp && prop.name.name == 'ref') {
        // Flag refs, since their type is likely to change.
        // fixme add note about type?
        yieldPatch(lineComment('FIXME(mui_migration) - ref - manually verify'),
            prop.assignment.offset, prop.assignment.offset);
      } else if (shouldFlagClassName && prop.name.name == 'className') {
        yieldPatch(
            lineComment('FIXME(mui_migration) - className - manually verify'),
            prop.assignment.offset,
            prop.assignment.offset);
      }
    }

    for (final prop in usage.cascadedIndexAssignments) {
      if (!isDataAttributePropKey(prop.index)) {
        yieldPatch(
            lineComment(
                'FIXME(mui_migration) - `..[propKey] =` - manually verify prop key'),
            prop.assignment.offset,
            prop.assignment.offset);
      }
    }
  }

  //
  // Helpers

  void flagUsageWithManualIntervention(FluentComponentUsage usage) {
    yieldPatch(blockComment('FIXME(mui_migration) needs manual intervention'),
        usage.node.end, usage.node.end);
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
              " not statically available on builder class '$builderClassName'."
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

  void yieldPatchOverNode(String updatedText, SyntacticEntity entityToReplace) {
    yieldPatch(updatedText, entityToReplace.offset, entityToReplace.end);
  }

  void yieldRemovePropPatch(PropAssignment prop) {
    yieldPatchOverNode('', prop.assignment);
  }

  void yieldPropPatch(
    PropAssignment prop, {
    String? newName,
    String? newRhs,
    String? additionalCascadeSection,
  }) {
    if (newName == null && newRhs == null) {
      throw ArgumentError.notNull('either newName or newValue');
    }

    if (newName != null) {
      yieldPatchOverNode(newName, prop.name);
    }

    if (newRhs != null) {
      yieldPatchOverNode(newRhs, prop.rightHandSide);
    }

    if (additionalCascadeSection != null) {
      // Add spaces so that dartfmt has a better time // todo is this necessary?
      yieldPatch('\n  $additionalCascadeSection', prop.rightHandSide.end,
          prop.rightHandSide.end);
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
    yieldPatch(
        lineComment('FIXME(mui_migration) - ${prop.name.name} prop - $message'),
        prop.assignment.offset,
        prop.assignment.offset);
  }
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

extension on PropAssignment {
  bool get isExtensionMethod =>
      assignment.staticElement?.isExtensionMethod ?? false;
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
  // fixme check package

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
