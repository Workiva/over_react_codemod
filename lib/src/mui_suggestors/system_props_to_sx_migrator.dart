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

import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';

/// A suggestor that migrates MUI system props to the `sx` prop.
///
/// MUI System props (such as `mt={*}`, `bgcolor={*}`, and more) have been deprecated
/// in MUI v6 in favor of the `sx` prop.
///
/// This migrator detects components that use system props and moves those props
/// to the `sx` prop, ensuring that existing `sx` prop values are preserved and merged correctly.
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

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final deprecatedSystemProps = <PropAssignment>[];
    PropAssignment? existingSxProp;

    // Identify system props and existing sx prop
    for (final prop in usage.cascadedProps) {
      final propName = prop.name.name;
      if (propName == 'sx') {
        existingSxProp = prop;
      } else if (_systemPropNames.contains(propName)) {
        final propElement = prop.staticElement?.nonSynthetic;
        final enclosingElement = propElement?.enclosingElement;
        late final componentName =
            enclosingElement?.name?.replaceAll(RegExp(r'Props(Mixin)?$'), '');
        if (propElement != null &&
            propElement.hasDeprecated &&
            enclosingElement != null &&
            _componentsWithDeprecatedSystemProps.contains(componentName) &&
            enclosingElement.isDeclaredInPackage('unify_ui')) {
          deprecatedSystemProps.add(prop);
        }
      }
    }

    if (deprecatedSystemProps.isEmpty) return;

    // FIXME comments don't come with props

    final migratedSystemPropEntries = deprecatedSystemProps.map((prop) {
      final propName = prop.name.name;
      final propValue = context.sourceFile
          .getText(prop.rightHandSide.offset, prop.rightHandSide.end);
      return "'$propName': $propValue";
    });

    // Remove all system props
    for (final prop in deprecatedSystemProps) {
      yieldRemovePropPatch(prop);
    }

    bool shouldForceMultiline(
        {required int elementCount, required int charCount}) {
      return elementCount >= 3 || (elementCount > 1 && charCount >= 20);
    }

    if (existingSxProp != null) {
      // FIXME before vs after
      final value = existingSxProp.rightHandSide;
      if (value is SetOrMapLiteral && value.isMap) {
        // Avoid inserting a double-comma if there's a trailing comma.
        // While we're here, also preserve the trailing comma.
        final hadTrailingComma =
            value.rightBracket.previous?.type == TokenType.COMMA;
        final maybePrecedingComma =
            !hadTrailingComma && value.elements.isNotEmpty ? ', ' : '';
        final maybeTrailingComma = hadTrailingComma ||
                shouldForceMultiline(
                  elementCount:
                      value.elements.length + migratedSystemPropEntries.length,
                  charCount: value.toSource().length +
                      migratedSystemPropEntries.join(', ').length,
                )
            ? ','
            : '';
        yieldPatch(
            '$maybePrecedingComma${migratedSystemPropEntries.join(', ')}$maybeTrailingComma',
            value.rightBracket.offset,
            value.rightBracket.offset);
      } else {
        final type = value.staticType;
        final nonNullable = type != null &&
            type is! DynamicType &&
            type.nullabilitySuffix == NullabilitySuffix.none;
        yieldPatch('{...${nonNullable ? '' : '?'}', value.offset, value.offset);
        final maybeTrailingComma = shouldForceMultiline(
                elementCount: migratedSystemPropEntries.length + 1,
                charCount: [value.toSource(), ...migratedSystemPropEntries]
                    .join(', ')
                    .length)
            ? ','
            : '';
        yieldPatch(
            ', ${migratedSystemPropEntries.join(', ')}$maybeTrailingComma}',
            value.end,
            value.end);
      }
    } else {
      final forwardedPropSources = _getForwardedPropSources(usage);
      final mightForwardSx = forwardedPropSources.any((source) {
        final type = source.propsExpression?.staticType?.typeOrBound
            .tryCast<InterfaceType>();
        if (type != null &&
            type.isPropsClass &&
            type.element.name != 'UiProps') {
          return type.element.lookUpGetter('sx', type.element.library) != null;
        }
        return true;
      });

      final String? additionalSxElement;
      final bool needsFixme;

      if (mightForwardSx) {
        var canGetForwardedSx = false;
        final forwardedProps =
            forwardedPropSources.singleOrNull?.propsExpression;
        if (forwardedProps != null &&
            (forwardedProps is Identifier ||
                forwardedProps is PropertyAccess)) {
          final forwardedPropsType =
              forwardedProps.staticType?.typeOrBound.tryCast<InterfaceType>();
          if (forwardedPropsType?.element
                  .lookUpGetter('sx', forwardedPropsType.element.library) !=
              null) {
            canGetForwardedSx = true;
          }
        }

        if (canGetForwardedSx) {
          additionalSxElement = '...?${forwardedProps!.toSource()}.sx';
          needsFixme = false;
        } else {
          additionalSxElement = null;
          needsFixme = true;
        }
      } else {
        additionalSxElement = null;
        needsFixme = false;
      }
      final fixme = needsFixme
          ? '\n ' +
              lineComment(
                  '$fixmePrefix - merge in any sx prop forwarded to this component, if needed')
          : '';

      final elements = [
        if (additionalSxElement != null) additionalSxElement,
        ...migratedSystemPropEntries,
      ];
      final maybeTrailingComma = shouldForceMultiline(
              elementCount: elements.length,
              charCount: elements.join(', ').length)
          ? ','
          : '';

      // Insert after any forwarded props to ensure sx isn't overwritten,
      // and where the last system prop used to be to preserve the location and reduce diffs.
      final insertionLocation = [
        ...forwardedPropSources.map((source) => source.cascadedMethod.node.end),
        deprecatedSystemProps.last.node.end
      ].reduce(max);

      yieldPatch('$fixme..sx = {${elements.join(', ')}$maybeTrailingComma}',
          insertionLocation, insertionLocation);
    }
  }
}

class _ForwardedPropSource {
  final BuilderMethodInvocation cascadedMethod;
  final Expression? propsExpression;

  _ForwardedPropSource(this.cascadedMethod, this.propsExpression);
}

/// Returns the set of expressions that are sources of props forwarded to the component in [usage],
/// or `null` for sources that were detected but don't cleanly map to a props expression.
List<_ForwardedPropSource> _getForwardedPropSources(
    FluentComponentUsage usage) {
  return usage.cascadedMethodInvocations
      .map((c) {
        final methodName = c.methodName.name;
        late final arg = c.node.argumentList.arguments.firstOrNull;

        switch (methodName) {
          case 'addUnconsumedProps':
            return _ForwardedPropSource(c, arg);
          case 'addAll':
          case 'addProps':
            if (arg is MethodInvocation &&
                arg.methodName.name == 'getPropsToForward') {
              return _ForwardedPropSource(c, arg.realTarget);
            }
            return _ForwardedPropSource(c, arg);
          case 'modifyProps':
            if ((arg is MethodInvocation &&
                arg.methodName.name == 'addPropsToForward')) {
              return _ForwardedPropSource(c, arg.realTarget);
            }
            if (arg is Identifier && arg.name == 'addUnconsumedProps') {
              return _ForwardedPropSource(c, null);
            }
            return _ForwardedPropSource(c, null);
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
