import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
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

  void migrateUsage(FluentComponentUsage usage);

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

extension MapKeyValueHelpers<K, V> on Map<K, V> {
  V? firstValueWhereOrNull(bool Function(K key, V value) test) => entries
      .where((element) => test(element.key, element.value))
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
