// Copyright 2026 Workiva Inc.
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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';

/// A suggestor that migrates deprecated MUI system props to the `sx` prop,
/// ensuring that existing `sx` prop values are preserved and merged correctly.
///
/// ### Example migration
///
/// Before:
/// ```dart
/// (Box()..m = 2)();
/// (Box()
///   ..m = 2
///   ..sx = {'color': '#f00'}
/// )()
/// (Box()
///   ..m = 2
///   ..addProps(props.getPropsToForward())
/// )()
/// ```
///
/// After
/// ```dart
/// (Box()..sx = {'m': 2})()
/// (Box()..sx = {
///   'm': 2,
///   'color': '#f00'
/// })()
/// (Box()
///   ..addProps(props.getPropsToForward())
///   ..sx = {
///     'm': 2,
///     ...?props.sx,
///   }
/// )()
/// ```
class SystemPropsToSxMigrator extends ComponentUsageMigrator {
  @override
  String get fixmePrefix => 'FIXME(mui_system_props_migration)';

  // We'll handle conditionally migrating when we collect more data in migrateUsage.
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => true;

  @override
  get safeMethodCallNames {
    return const {
      // These are handled in getForwardedPropSources
      'addUnconsumedProps',
      'addAll',
      'addProps',
      'modifyProps',
      // These are unrelated
      'addUnconsumedDomProps',
      'addAutomationId',
      'addTestId',
    };
  }

  @override
  get shouldFlagExtensionMembers => false;

  @override
  get shouldFlagUntypedSingleProp => false;

  @override
  get shouldFlagPrefixedProps => false;

  @override
  get shouldFlagRefProp => false;

  @override
  get shouldFlagClassName => false;

  bool isFirstTokenOnLine(Token token) {
    final sourceFile = context.sourceFile;
    final lineStart = sourceFile.getOffset(sourceFile.getLine(token.offset));
    return sourceFile.getText(lineStart, token.offset).trim().isEmpty;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final systemProps = <PropAssignment>[];
    PropAssignment? existingSxProp;

    // Identify system props and existing sx prop
    for (final prop in usage.cascadedProps) {
      final propName = prop.name.name;
      if (propName == 'sx') {
        existingSxProp = prop;
      } else if (_systemPropNames.contains(propName)) {
        final propClassElement = prop.staticElement?.enclosingElement;
        final componentName =
            propClassElement?.name?.replaceAll(RegExp(r'Props(Mixin)?$'), '');
        if (propClassElement != null &&
            _componentsWithDeprecatedSystemProps.contains(componentName) &&
            propClassElement.isDeclaredInPackage('unify_ui')) {
          systemProps.add(prop);
        }
      }
    }

    // No system props to migrate; bail out for this usage.
    if (systemProps.isEmpty) return;

    final migratedSystemPropEntries = <String>[];
    for (final prop in systemProps) {
      final propName = prop.name.name;
      final propValue = context.sourceFile
          .getText(prop.rightHandSide.offset, prop.rightHandSide.end);

      // Carry over comments before the node
      // (we won't try to handle end-of-line comments).
      final beforeComments = allCommentsForNode(prop.node)
          // Don't include end-of-line comments that should stay with the previous line.
          .skipWhile((comment) => !isFirstTokenOnLine(comment))
          .toList();

      final commentSource = beforeComments.isEmpty
          ? ''
          // Get full comment text, and trim trailing newline/whitespace
          : context.sourceFile
              .getText(beforeComments.first.offset, beforeComments.last.end)
              .trimRight();

      // Create new sx entry
      migratedSystemPropEntries.add([
        if (commentSource.isNotEmpty) '\n $commentSource',
        "'$propName': $propValue"
      ].join('\n'));

      // Remove old system prop
      yieldPatch('', beforeComments.firstOrNull?.offset ?? prop.node.offset,
          prop.node.end);
    }

    final propForwardingSources = _detectPropForwardingSources(usage);

    final fixmes = <String>[];
    if (propForwardingSources.isNotEmpty) {
      final propForwardingOffsets =
          propForwardingSources.map((s) => s.cascadedMethod.node.end).toList();
      final systemPropOffsets = systemProps.map((p) => p.node.end).toList();
      final anySystemPropSetBeforeForwarding =
          systemPropOffsets.min < propForwardingOffsets.max;
      if (anySystemPropSetBeforeForwarding) {
        fixmes.add(
            'Previously, it was possible for forwarded system props to overwrite these migrated styles, but not anymore since sx takes precedence over any system props.'
            '\n Double-check that this new behavior is okay.');
      }
    }

    String getFixmesSource() {
      if (fixmes.isEmpty) return '';
      // Add a leading newline to ensure comments don't get stuck to the previous line.
      return '\n' +
          fixmes
              // Indent with a single space so that dartfmt doesn't make it stick to the beginning of the line.
              .map((f) => lineComment('$fixmePrefix - $f', indent: ' '))
              .join('');
    }

    if (existingSxProp != null) {
      //
      // Case 1: add styles to existing sx prop value
      final value = existingSxProp.rightHandSide;
      if (value is SetOrMapLiteral && value.isMap) {
        //
        // Case 1a: add styles to existing sx map literal

        // Insert before, to preserve existing behavior where any spread sx trumped these styles.
        // Add a leading newline to ensure comments don't get stuck to the opening braces.
        yieldPatch(
            '${getFixmesSource()}\n${migratedSystemPropEntries.join(',\n')},',
            value.leftBracket.end,
            value.leftBracket.end);
        // Force a multiline in all cases by ensuring there's a trailing comma.
        final hadTrailingComma =
            value.rightBracket.previous?.type == TokenType.COMMA;
        if (!hadTrailingComma && value.elements.isNotEmpty) {
          yieldPatch(',', value.rightBracket.offset, value.rightBracket.offset);
        }
      } else {
        //
        // Case 1b: spread existing sx value into a new map literal

        final type = value.staticType;
        final nonNullable = type != null &&
            type is! DynamicType &&
            type.nullabilitySuffix == NullabilitySuffix.none;
        final spread = '...${nonNullable ? '' : '?'}';
        // Insert before spread, to preserve existing behavior where any forwarded sx trumped these styles.
        yieldPatch(
            '{${getFixmesSource()}\n${migratedSystemPropEntries.join(', ')}, $spread',
            value.offset,
            value.offset);
        final maybeTrailingComma = _shouldForceMultiline([
          ...migratedSystemPropEntries,
          '$spread${context.sourceFor(value)}',
        ])
            ? ','
            : '';
        yieldPatch('$maybeTrailingComma}', value.end, value.end);
      }
    } else {
      //
      // Case 2: add new sx prop assignment

      final String? forwardedSxSpread;

      final mightForwardSx = propForwardingSources.any((source) {
        final type = source.sourceProps?.staticType?.typeOrBound
            .tryCast<InterfaceType>();
        if (type != null &&
            type.isPropsClass &&
            type.element.name != 'UiProps') {
          return type.element.lookUpGetter('sx', type.element.library) != null;
        }
        return true;
      });

      if (mightForwardSx) {
        // Try to access the forwarded sx prop to merge it in.
        bool canSafelyGetForwardedSx;
        final props = propForwardingSources.singleOrNull?.sourceProps;
        if (props != null && (props is Identifier || props is PropertyAccess)) {
          final propsElement =
              props.staticType?.typeOrBound.tryCast<InterfaceType>()?.element;
          canSafelyGetForwardedSx =
              propsElement?.lookUpGetter('sx', propsElement.library) != null;
        } else {
          canSafelyGetForwardedSx = false;
        }

        if (canSafelyGetForwardedSx) {
          forwardedSxSpread = '...?${context.sourceFor(props!)}.sx';
        } else {
          forwardedSxSpread = null;
          fixmes.add(
              'spread in any sx prop forwarded to this component above, if needed (spread should go at the end of this map to preserve behavior)');
        }
      } else {
        forwardedSxSpread = null;
      }

      final elements = [
        // Insert before spread, to preserve existing behavior where any forwarded sx trumped these styles.
        ...migratedSystemPropEntries,
        if (forwardedSxSpread != null) forwardedSxSpread,
      ];
      final maybeTrailingComma = _shouldForceMultiline(elements) ? ',' : '';

      // Insert after any forwarded props to ensure sx isn't overwritten,
      // or where the last system prop used to be to preserve the location and reduce diffs,
      // whichever is later.
      final insertionLocation = [
        ...propForwardingSources.map((s) => s.cascadedMethod.node.end),
        ...systemProps.map((p) => p.node.end)
      ].max;

      yieldPatch(
          '${getFixmesSource()}..sx = {${elements.join(', ')}$maybeTrailingComma}',
          insertionLocation,
          insertionLocation);
    }
  }

  static bool _shouldForceMultiline(List<String> mapElements) =>
      // Force multiline if there are a certain number of entries, or...
      mapElements.length >= 3 ||
      // there's more than one entry and the line is getting too long, or...
      (mapElements.length > 1 && mapElements.join(', ').length >= 20) ||
      // any entry is multiline (including comments).
      mapElements.any((e) => e.contains('\n'));
}

/// A source of props being added (spread) to a component usage.
class _PropSpreadSource {
  /// The cascaded invocation that adds props.
  final BuilderMethodInvocation cascadedMethod;

  /// And expression representing the source of the props being spread,
  /// or null if the source is more complex or could not be resolved.
  ///
  /// Handles common prop forwarding expressions, returning the original
  /// expression that the subsetted forwarded props are coming from.
  ///
  /// For example, this expression would be:
  ///
  /// - for `..addAll(getSomeProps())` - `getSomeProps()`
  /// - for `..addProps(props.getPropsToForward({FooProps}))` - `props`
  /// - for `..modifyProps(somePropsModifier)` - props
  final Expression? sourceProps;

  _PropSpreadSource(this.cascadedMethod, this.sourceProps);
}

/// Returns the sources of props being added or spread to [usage].
List<_PropSpreadSource> _detectPropForwardingSources(
    FluentComponentUsage usage) {
  return usage.cascadedMethodInvocations
      .map((c) {
        final methodName = c.methodName.name;
        late final arg = c.node.argumentList.arguments.firstOrNull;

        switch (methodName) {
          case 'addUnconsumedProps':
            return _PropSpreadSource(c, arg);
          case 'addAll':
          case 'addProps':
            if (arg is MethodInvocation &&
                arg.methodName.name == 'getPropsToForward') {
              return _PropSpreadSource(c, arg.realTarget);
            }
            return _PropSpreadSource(c, arg);
          case 'modifyProps':
            if ((arg is MethodInvocation &&
                arg.methodName.name == 'addPropsToForward')) {
              return _PropSpreadSource(c, arg.realTarget);
            }
            if (arg is Identifier && arg.name == 'addUnconsumedProps') {
              return _PropSpreadSource(c, null);
            }
            return _PropSpreadSource(c, null);
          default:
            // Not a method that forwards props.
            return null;
        }
      })
      .whereNotNull()
      .toList();
}

const _componentsWithDeprecatedSystemProps = {
  'Box',
  'Grid',
  'Stack',
  'Typography',
};

const _systemPropNames = {
  'm',
  'mt',
  'mr',
  'mb',
  'ml',
  'mx',
  'my',
  'p',
  'pt',
  'pr',
  'pb',
  'pl',
  'px',
  'py',
  'width',
  'maxWidth',
  'minWidth',
  'height',
  'maxHeight',
  'minHeight',
  'boxSizing',
  'display',
  'displayPrint',
  'overflow',
  'textOverflow',
  'visibility',
  'whiteSpace',
  'flexBasis',
  'flexDirection',
  'flexWrap',
  'justifyContent',
  'alignItems',
  'alignContent',
  'order',
  'flex',
  'flexGrow',
  'flexShrink',
  'alignSelf',
  'justifyItems',
  'justifySelf',
  'gap',
  'columnGap',
  'rowGap',
  'gridColumn',
  'gridRow',
  'gridAutoFlow',
  'gridAutoColumns',
  'gridAutoRows',
  'gridTemplateColumns',
  'gridTemplateRows',
  'gridTemplateAreas',
  'gridArea',
  'bgcolor',
  'color',
  'zIndex',
  'position',
  'top',
  'right',
  'bottom',
  'left',
  'boxShadow',
  'border',
  'borderTop',
  'borderRight',
  'borderBottom',
  'borderLeft',
  'borderColor',
  'borderRadius',
  'fontFamily',
  'fontSize',
  'fontStyle',
  'fontWeight',
  'letterSpacing',
  'lineHeight',
  'textAlign',
  'textTransform',
  'margin',
  'marginTop',
  'marginRight',
  'marginBottom',
  'marginLeft',
  'marginX',
  'marginY',
  'marginInline',
  'marginInlineStart',
  'marginInlineEnd',
  'marginBlock',
  'marginBlockStart',
  'marginBlockEnd',
  'padding',
  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',
  'paddingX',
  'paddingY',
  'paddingInline',
  'paddingInlineStart',
  'paddingInlineEnd',
  'paddingBlock',
  'paddingBlockStart',
  'paddingBlockEnd',
  'typography',
};
