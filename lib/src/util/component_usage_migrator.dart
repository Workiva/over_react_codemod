// Copyright 2021 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
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

/// A base class/mixin for a suggestor that resolves each file, identifies all
/// OverReact component usages, and iterates through each of them.
///
/// Throws if any file cannot be resolved or if any of the OverReact component
/// usages could not be fully resolved.
///
/// Consumers should override:
/// - [shouldMigrateUsage] to determine whether a usage should be migrated
/// - [migrateUsage] to preform migration logic.
///
/// [migrateUsage] also always calls [flagCommon], which flags common cascaded
/// members with fix-me comments indicating manual migration is necessary.
/// See [flagCommon]'s doc comment for more information.
///
/// For example:
///
/// ```dart
/// class MuiButtonToolbarMigrator with ClassSuggestor, ComponentUsageMigrator {
///   @override
///   bool shouldMigrateUsage(FluentComponentUsage usage) =>
///       // Only migrate certain factories
///       usesWsdFactory(usage, 'OldFactory');
///
///   @override
///   void migrateUsage(FluentComponentUsage usage) {
///     super.migrateUsage(usage);
///
///     // Update the factory
///     yieldPatchOverNode('NewFactory', usage.factory!);
///
///     // Update props
///     handleCascadedPropsByName(usage, {
///       'oldProp': (p) => yieldPropPatch(p, newName: 'newProp'),
///     })
///   }
/// }
/// ```
///
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
abstract class ComponentUsageMigrator with ClassSuggestor {
  static final _log = Logger('ComponentUsageMigrator');

  /// Returns whether [migrateUsage] should be called for a specific [usage].
  bool shouldMigrateUsage(FluentComponentUsage usage);

  /// Migrates a given [usage] if [shouldMigrateUsage] returned `true` for it.
  ///
  /// This method should typically be overridden and used to perform custom
  /// migration of a usage (e.g., update its factory and/or props).
  ///
  /// This also calls [flagCommon], which flags common cascaded members with
  /// fix-me comments indicating manual migration is necessary.
  /// See that method's doc comment for more info.
  @mustCallSuper
  void migrateUsage(FluentComponentUsage usage) {
    flagCommon(usage);
  }

  static const _fatalUnresolvedUsages = true;

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

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
            .spanFor(usage.factory ?? usage.builder)
            .message('Skipping ignored usage'));
        continue;
      }

      // If things aren't fully resolved, the unresolved branch of the FluentComponentUsage
      // detection will be used. Check for that here, since that probably means
      // the library declaring the component wasn't resolved, and we want to know
      // about it so the component isn't skipped over silently (since the checks
      // to see what component it is often rely on resolved AST).
      if (_fatalUnresolvedUsages) {
        _verifyUsageIsResolved(usage, result);
      }

      if (shouldMigrateUsage(usage)) {
        migrateUsage(usage);
      }
    }
  }

  Exception _unresolvedException(String message, SyntacticEntity entity) {
    const commonMessage =
        'Check that `pub get` has been run and that this is a valid over_react component usage.';
    final span = context.sourceFile.span(entity.offset, entity.end);
    return Exception(span.message('$message$commonMessage'));
  }

  /// Verifies a given usage's builder is fully resolved, throwing a helpful error message if not.
  ///
  /// This allows custom migration code to assume that all usages are fully resolved,
  /// and thus can rely on static typing and other static information being available.
  void _verifyUsageIsResolved(
      FluentComponentUsage usage, ResolvedUnitResult result) {
    String errorsMessage() => result.errors.isEmpty
        ? ''
        : ' \nAnalysis errors in file:\n${prettyPrintErrors(result.errors)}\n'
            // TODO - reference analyzer issue for this once it's created
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
  bool get shouldFlagClassName => true;

  /// Flags common cascaded members with fix-me comments indicating manual
  /// migration is necessary.
  ///
  /// This includes:
  /// - unsafe method calls, which could perform unknown mutations to a builder's props map
  ///     - Examples: `..addProps(somePropsMap)`, `..modifyProps(someFunction)`
  /// - setting untyped props (excluding data-attributes)
  ///     - Examples: `..addProp('someProp', value)`, `..['someProp'] = value`
  /// - prefixed props (excluding `dom` and `aria` props)
  ///     - Example: `..foo.bar = value`
  /// - extension getters/setters, which could perform unknown mutations to a builder's props map
  /// - ref props, whose typings almost always need to be updated when changing components
  /// - className props, which may need to be manually verified when changing components
  ///
  /// To disable specific checks, override one of the `shouldFlag*` getters
  /// in this class.
  void flagCommon(FluentComponentUsage usage) {
    // Flag things like addProps, addAll, modifyProps, which could be adding
    // props for the old component.
    // This also handles extension methods.
    for (final method in usage.cascadedMethodInvocations) {
      final name = method.methodName.name;

      if (methodsWithCustomHandling.contains(name)) {
        switch (name) {
          case 'addProp':
            if (shouldFlagUntypedSingleProp) {
              final expression = method.node.argumentList.arguments.firstOrNull;
              if (expression != null && !_isDataAttributePropKey(expression)) {
                yieldBuilderMemberFixmePatch(
                    method, '$name - manually verify prop key');
              }
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
        yieldPropFixmePatch(prop, 'manually verify (see doc for more details)');
      } else if (shouldFlagPrefixedProps &&
          prop.prefix != null &&
          !safePropPrefixes.contains(prop.prefix!.name)) {
        yieldBuilderMemberFixmePatch(
            prop, '${prop.prefix!.name} (prefix) - manually verify');
      }
    }

    for (final prop in usage.cascadedIndexAssignments) {
      if (shouldFlagUntypedSingleProp && !_isDataAttributePropKey(prop.index)) {
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

  /// Yields a patch that replaces a given [AstNode]/[Token] ([entityToReplace]),
  /// for convenience.
  void yieldPatchOverNode(String updatedText, SyntacticEntity entityToReplace) {
    yieldPatch(updatedText, entityToReplace.offset, entityToReplace.end);
  }

  /// Yields a patch that removes a given [prop].
  void yieldRemovePropPatch(PropAssignment prop) {
    yieldPatchOverNode('', prop.node);
  }

  /// Yields a patch adds a prop (or any other cascade) to a given [usage]
  /// with the given [placement].
  ///
  /// [newPropCascade] should include the leading `..`.
  ///
  /// Automatically adds parentheses around the builder if they don't already
  /// exist.
  void yieldAddPropPatch(FluentComponentUsage usage, String newPropCascade,
      {NewPropPlacement placement = NewPropPlacement.auto}) {
    final function = usage.node.function;
    if (function is ParenthesizedExpression) {
      int getInsertionOffsetWithinBuilderOnNextLineIfPossible(int offset) =>
          min(
            context.sourceFile.getOffsetOfLineAfter(offset),
            // Ensure this position isn't outside of the cascade parens
            // (e.g., single-line cascade, multiline cascade with non-aligned right paren).
            function.rightParenthesis.offset,
          );

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
              ? getInsertionOffsetWithinBuilderOnNextLineIfPossible(
                  propToInsertAfter.node.end)
              : function.rightParenthesis.offset;
          break;
        case NewPropPlacement.start:
          // TODO would it be better formatting and insertion-wise to attempt to insert at the beginning of the line of the first prop (similar to above)?
          offset = usage.cascadeExpression != null
              ? getInsertionOffsetWithinBuilderOnNextLineIfPossible(
                  usage.cascadeExpression!.offset)
              : function.rightParenthesis.offset;
          break;
        case NewPropPlacement.end:
          // TODO would it be better formatting and insertion-wise to attempt to insert at the beginning of the line after the last prop (similar to above)?
          offset = function.rightParenthesis.offset;
          break;
      }
      yieldInsertionPatch('$newPropCascade\n', offset);
    } else {
      assert(usage.cascadeExpression == null);

      yieldInsertionPatch('(', function.offset);
      yieldInsertionPatch(newPropCascade, function.end);
      // Separate the closing paren and the cascade patches so that they can be
      // applied separately if there are other calls to addProp.
      yieldInsertionPatch(')', function.end);
    }
  }

  /// Yields a patch that removes a given [child] from a usage, and also
  /// conditionally removes commas so as to preserve trailing or non-trailing
  /// commas in the parent argument list or list literal.
  void yieldRemoveChildPatch(AstNode child) {
    // This logic is a little extra, but isn't too much effort and helps keep things tidy.

    final int start;
    final int end;

    // If there's a comma after the child, remove it with the child.
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
        // There's no comma, and we probably have a single child. Just remove the child itself.
        start = child.offset;
        end = child.end;
      }
    }
    yieldPatch('', start, end);
  }

  /// Yields a patch that adds a given [child] to a usage.
  ///
  /// If children are already present in the usage, the given [child] will
  /// become the first child of the usage.
  void yieldAddChildPatch(FluentComponentUsage usage, String child) {
    final int start;

    child = child + ',';

    if (usage.children.isNotEmpty) {
      start = usage.children.first.node.offset;
    } else {
      // If the usage's children is considered empty but its argument list is not,
      // the usage has an empty list as its children.
      if (usage.node.argumentList.arguments.length == 1) {
        final childList = usage.node.argumentList.arguments.first;

        start = childList.offset + 1;
      } else {
        start = usage.node.argumentList.offset + 1;
      }
    }

    yieldPatch(child, start, start);
  }

  /// Yields a patch that updates a prop, updating either its name ([newName]),
  /// its right-hand side ([newRhs]), or both, and optionally adding an
  /// [additionalCascadeSection].
  ///
  /// This method makes it convenient to update props without dealing with offsets.
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

  /// The prefix for FIX-ME comments added in the various yield* methods in this class.
  ///
  /// E.g., `'FIXME'`, `'FIXME(something_more_specific)'`.
  String get fixmePrefix;

  /// Yields a patch with a fix-me comment before a given component [usage]
  /// with a custom [message].
  void yieldUsageFixmePatch(FluentComponentUsage usage, String message) {
    yieldInsertionPatch(
        lineComment('$fixmePrefix $message'), usage.node.offset);
  }

  void yieldPropManualMigratePatch(PropAssignment prop) {
    yieldPropFixmePatch(prop, 'manually migrate');
  }

  /// Yields a patch with a fix-me comment before a given [prop]
  /// with a custom [message].
  ///
  /// Inserts extra newlines as necessary to avoid the comment getting "stuck"
  /// to the previous line, or adding blank lines.
  ///
  /// For example:
  /// ```dart
  /// // Flagging "id" for this usage...
  /// (Dom.div()..id = '')();
  ///
  /// // ...results in this...
  /// (Dom.div()
  ///   // FIXME ...
  ///   ..id = ''
  /// )();
  ///
  /// // ...and not this...
  /// (Dom.div() // FIXME ...
  ///   ..id = ''
  /// )();
  /// ```
  void yieldPropFixmePatch(PropAssignment prop, String message) {
    yieldBuilderMemberFixmePatch(prop, '${prop.name.name} prop - $message');
  }

  /// Yields a patch with a fix-me comment before a given [access]
  /// with a custom [message].
  ///
  /// Inserts extra newlines as necessary to avoid the comment getting "stuck"
  /// to the previous line, or adding blank lines.
  ///
  /// For example:
  /// ```dart
  /// // Flagging "id" for this usage...
  /// (Dom.div()..id = '')();
  ///
  /// // ...results in this...
  /// (Dom.div()
  ///   // FIXME ...
  ///   ..id = ''
  /// )();
  ///
  /// // ...and not this...
  /// (Dom.div() // FIXME ...
  ///   ..id = ''
  /// )();
  /// ```
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
            lineComment('$fixmePrefix - $message'),
        access.node.offset);
  }

  /// Yields a patch with a fix-me comment before a given [child]
  /// with a custom [message].
  ///
  /// Inserts extra newlines as necessary to avoid the comment getting "stuck"
  /// to the previous line, or adding blank lines.
  ///
  /// For example:
  /// ```dart
  /// // Flagging the single child for this usage...
  /// Dom.div()('child');
  ///
  /// // ...results in this...
  /// Dom.div()(
  ///   // FIXME
  ///   'child'
  /// );
  ///
  /// // ...and not this...
  /// Dom.div()( // FIXME ...
  ///   'child'
  /// );
  /// ```
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
            lineComment('$fixmePrefix - $message'),
        child.node.beginToken.offset);
  }

  void yieldPatchOverChildNode(String updatedText, ComponentChild child) {
    int start = child.node.offset;
    int end = child.node.end;
    final needsLeadingNewline = context.sourceFile.getLine(child.node.parent!
            .thisOrAncestorOfType<InvocationExpression>()!
            .argumentList
            .leftParenthesis
            .end) ==
        context.sourceFile.getLine(child.node.offset);
    // If there's a comma after the child, remove it with the child.
    final nextToken = child.node.endToken.next;
    if (nextToken != null && nextToken.type == TokenType.COMMA) {
      start = child.node.offset;
      end = nextToken.end;
    }
    yieldPatch((needsLeadingNewline ? '\n' : '') + updatedText,
        start, end);

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

    if (ignoreInfo.allCodesIgnoredAt(line)) {
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

/// Where to place a newly-inserted prop.
///
/// See [ComponentUsageMigrator.yieldAddPropPatch].
enum NewPropPlacement {
  /// Automatically place the prop in the best position, based on conventions
  /// (after cascaded method calls like `modifyProps`/`addProps` and before
  /// props like `key` and `addTestId`).
  auto,

  /// Place the prop at the beginning of the cascade.
  start,

  /// Place the prop at the end of the cascade.
  end,
}

/// Returns the values in [propNames] that do not correspond to the names of
/// statically declared props in [usage]'s static type.
Iterable<String> _getUnknownPropNames(
    FluentComponentUsage usage, Iterable<String> propNames) {
  final propsClassElement = usage.propsClassElement;
  if (propsClassElement != null) {
    final library =
        usage.builder.root.tryCast<CompilationUnit>()?.declaredElement!.library;
    if (library != null) {
      return propNames
          .where((propName) =>
              propsClassElement.lookUpSetter(propName, library) == null)
          .toList();
    }
  }

  return [];
}

/// Returns the first cascaded prop assignment in [usage] whose name matches [name].
///
/// Throws if [name] is not statically declared in [usage]'s static type,
/// to help guard against typos in props names that could cause silent failures
/// (or more likely, frustration while authoring/debugging codemods).
PropAssignment? getFirstPropWithName(FluentComponentUsage usage, String name) {
  final unknownPropNames = _getUnknownPropNames(usage, [name]);
  if (unknownPropNames.isNotEmpty) {
    throw ArgumentError("prop '$name' is"
        " not statically available on builder class '${usage.propsClassElement?.name}'"
        " (declared in ${usage.propsClassElement?.enclosingElement.source.uri})."
        " Double-check that that prop exists in that props class"
        " and that the key in 'migratorsByName' does not have any typos.");
  }

  return usage.cascadedProps
      .firstWhereOrNull((element) => element.name.name == name);
}

/// Iterates over the cascaded prop assignments in [usage] and calls the matching
/// handler functions in [propHandlersByName], where keys are prop names and values
/// are the handler functions.
///
/// If there is no handler for a given prop name, [catchAll] is called instead.
///
/// This makes writing migration logic for multiple props easier. For example:
/// ```dart
/// handleCascadedPropsByName(usage, {
///   'isDisabled': (p) => yieldPropPatch(p, newName: 'disabled'),
///   'isVertical': migrateIsVertical,
///   'size': migrateSize,
/// });
/// ```
///
/// Throws if any of the names in [propHandlersByName] are not
/// statically declared in [usage]'s static type,
/// to help guard against typos in props names that could cause silent failures
/// (or more likely, frustration while authoring/debugging codemods).
void handleCascadedPropsByName(
  FluentComponentUsage usage,
  Map<String, void Function(PropAssignment)> propHandlersByName, {
  void Function(PropAssignment)? catchAll,
}) {
  final unknownPropNames = _getUnknownPropNames(usage, propHandlersByName.keys);
  if (unknownPropNames.isNotEmpty) {
    throw ArgumentError(
        "'migratorsByName' contains unknown prop name(s) '$unknownPropNames'"
        " not statically available on builder class '${usage.propsClassElement?.name}'"
        " (declared in ${usage.propsClassElement?.enclosingElement.source.uri})."
        " Double-check that that prop exists in that props class"
        " and that the key in 'migratorsByName' does not have any typos.");
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
  /// Whether the member represented by this element
  /// is declared in a static extension.
  bool get isExtensionMember {
    final self = this;
    return enclosingElement is ExtensionElement &&
        self is ExecutableElement &&
        !self.isStatic;
  }
}

extension on PropRead {
  /// Whether the static element of the property being accessed
  /// is declared in a static extension.
  bool get isExtensionMethod {
    final staticElement = node.propertyName.staticElement;
    return staticElement?.isExtensionMember ?? false;
  }
}

extension on PropAssignment {
  /// Whether the static element of the prop being set
  /// is declared in a static extension.
  bool get isExtensionMethod {
    // Make sure to use `.writeElement` since `.staticElement` is null for assignments.
    // https://github.com/dart-lang/sdk/issues/44415#issuecomment-740354773
    final staticElement = node.writeElement;
    return staticElement?.isExtensionMember ?? false;
  }
}

extension on MethodInvocation {
  /// Whether this method element of this invocation
  /// is declared in a static extension.
  bool get isExtensionMethod =>
      methodName.staticElement?.isExtensionMember ?? false;
}
