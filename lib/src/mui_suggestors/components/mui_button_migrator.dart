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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import '../constants.dart';
import 'mui_migrator.dart';

const _linkButtonSkin = 'ButtonSkin.LINK';
const _outlineLinkButtonSkin = 'ButtonSkin.OUTLINE_LINK';

const _linkButtonSkins = {
  _linkButtonSkin,
  _outlineLinkButtonSkin,
};

class MuiButtonMigrator extends ComponentUsageMigrator
    with MuiMigrator, ButtonDisplayPropsMigrator {
  static bool hasLinkButtonSkin(FluentComponentUsage usage) => usage
      .cascadedProps
      .any((p) => p.name.name == 'skin' && isLinkButtonSkin(p.rightHandSide));

  static bool isLinkButtonSkin(Expression expr) =>
      _linkButtonSkins.any((linkSkin) => isWsdStaticConstant(expr, linkSkin));

  static bool isLikelyAssignedToButtonAddonProp(FluentComponentUsage usage) =>
      usage.node.ancestors.whereType<AssignmentExpression>().map((e) {
        // Get the resolved name of the property being assigned so we don't have
        // to handle as many unresolved AST cases.
        final writeElement = e.writeElement;
        if (writeElement == null) return null;
        return writeElement is PropertyAccessorElement
            // Use variable.name since PropertyAccessorElement's name has a trailing `=`
            ? writeElement.variable.name
            : writeElement.name;
      }).any(const {'buttonBefore', 'buttonAfter'}.contains);

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      const {
        'Button',
        'FormSubmitInput',
        'FormResetInput',
      }.any((wsdFactory) => usesWsdFactory(usage, wsdFactory)) &&
      !usesWsdToolbarFactory(usage) &&
      !isLikelyAssignedToButtonAddonProp(usage);

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final newFactory =
        hasLinkButtonSkin(usage) ? '$muiNs.LinkButton' : '$muiNs.Button';
    yieldPatchOverNode(newFactory, usage.factory!);

    // Needed so we can  only attempt to migrate certain props if they're
    // declared on the props class, so that handleCascadedPropsByName/getFirstPropWithName doesn't throw.
    bool propsClassHasHitareaMixin;
    if (usesWsdFactory(usage, 'FormSubmitInput')) {
      // Avoid adding two props separately at the same time when there are no
      // no parens around the builder, which yields the following diff:
      // - FormSubmitInput()('Create Item'),
      // + ((mui.Button()..color = mui.ButtonColor.primary..type = 'submit'))('Create Item')
      // Normally this isn't a big deal and doesn't happen often, but for this
      // factory it's really common to not have any parens/props.

      final colorPatch = '..color = $muiPrimaryColor';
      const typePatch = "..type = ${_MuiButtonType.submit}";

      if (usage.node.function is! ParenthesizedExpression) {
        yieldAddPropPatch(usage, colorPatch + typePatch);
      } else {
        yieldAddPropPatch(usage, colorPatch, placement: NewPropPlacement.start);
        yieldAddPropPatch(usage, typePatch, placement: NewPropPlacement.end);
      }

      propsClassHasHitareaMixin =
          wsdComponentVersionForFactory(usage) != WsdComponentVersion.v1;
    } else if (usesWsdFactory(usage, 'FormResetInput')) {
      yieldAddPropPatch(usage, "..type = ${_MuiButtonType.reset}",
          placement: NewPropPlacement.end);

      propsClassHasHitareaMixin =
          wsdComponentVersionForFactory(usage) != WsdComponentVersion.v1;
    } else {
      assert(usesWsdFactory(usage, 'Button'));
      propsClassHasHitareaMixin = true;
    }

    handleCascadedPropsByName(usage, {
      // Simple replacements.
      'isActive': (p) => yieldPropPatch(p, newName: 'aria.pressed'),
      'isBlock': (p) => yieldPropPatch(p, newName: 'fullWidth'),
      'isFlat': (p) => yieldPropPatch(p, newName: 'disableElevation'),
      if (propsClassHasHitareaMixin) ...{
        'role': (p) => yieldPropPatch(p, newName: 'dom.role'),
        'target': (p) => yieldPropPatch(p, newName: 'dom.target'),
      },

      // Related to disabled state
      'isDisabled': (p) {
        yieldPropFixmePatch(p,
            'if this button has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element');
        yieldPropPatch(p, newName: 'disabled');
      },
      if (propsClassHasHitareaMixin)
        'allowedHandlersWhenDisabled': yieldPropManualMigratePatch,

      // Lengthier migration code; split out into methods.
      'skin': (p) => migrateButtonSkin(p, handleLinkVariants: true),
      'size': migrateButtonSize,
      if (propsClassHasHitareaMixin) 'type': migrateButtonType,

      // Props that always need manual intervention.
      'isCallout': (p) => yieldPropFixmePatch(
          p,
          "this styling can be recreated using"
          " `..sx = const {'textTransform': 'uppercase', 'fontWeight': 'bold'}`"),
      'pullRight': (p) => yieldPropFixmePatch(
          p,
          "this styling can be recreated using"
          " `..sx = const {'float': 'right'}`"
          " (or by adjusting the parent layout)"),
    });

    // Only attempt to migrate these props if they're declared on the props class
    // (since we'll get errors otherwise).
    if (propsClassHasHitareaMixin) {
      migrateTooltipProps(usage);
    }

    migrateChildIcons(usage);

    // It's almost impossible to tell with certainty which components a component
    // is nested within, so instead we'll just use the presence of that component
    // name in the file as a heuristic, and flag migrated buttons to be
    // manually checked.
    if (context.sourceText.contains('DialogFooter')) {
      yieldUsageFixmePatch(
          usage,
          "check whether this button is nested inside a DialogFooter."
          " If so, wrap it in a $muiNs.ButtonToolbar with `..sx = {'float': 'right'}`.");
    }
    if (context.sourceText
        .contains(RegExp(r'\b(?:buttonBefore|buttonAfter)\b'))) {
      yieldUsageFixmePatch(
          usage,
          "check whether this button is assigned to a buttonBefore or buttonAfter prop."
          " If so, revert the changes to this usage and add an `orcm_ignore` comment to it.");
    }
  }

  /// Returns a string that can be used to add the props from the right-hand
  /// side of [assignment] (assuming the prop is a Map prop) to a factory
  /// matching [destinationFactoryName].
  ///
  /// If the map prop value is a typed map constructed from [destinationFactoryName],
  /// then just the cascades will be returned.
  ///
  /// For example, for the assignment:
  /// ```dart
  /// ..fooProps = (Foo()
  ///   ..bar = 'bar'
  ///   ..id = foo
  /// )
  /// ```
  /// then `_cascadeFromMapPropValue(assignment, 'Foo')`
  /// would yield the string:
  /// ```
  /// ..bar = 'bar'
  /// ..id = 'foo'
  /// ```
  ///
  /// Non-matching values are handled using `.addProps`, so
  /// `_cascadeFromMapPropValue(assignment, 'Bar')`
  /// would yield the string:
  /// ```
  /// ..addProps(Foo()
  ///   ..bar = 'bar'
  ///   ..id = 'foo'
  /// )
  /// ```
  ///
  /// Non-typed-map values are also handled using `.addProps`.
  ///
  /// For example, for the assignment:
  /// ```dart
  /// ..fooProps = someValue
  /// ```
  /// then `_cascadeFromMapPropValue(assignment, 'Foo')`
  /// would yield the string:
  /// ```
  /// ..addProps(someValue)
  /// ```
  String _cascadeFromMapPropValue(PropAssignment? assignment,
      {required String destinationFactoryName}) {
    if (assignment == null) return '';

    // If the RHS is a maps view using destinationFactoryName,
    // then we can just return that cascade directly.
    final value = assignment.rightHandSide.unParenthesized;
    if (value is CascadeExpression) {
      final function = value.target.tryCast<InvocationExpression>()?.function;
      if (function.tryCast<SimpleIdentifier>()?.name ==
              destinationFactoryName ||
          function.tryCast<PrefixedIdentifier>()?.identifier.name ==
              destinationFactoryName) {
        return context.sourceFile.getText(value.target.end, value.end);
      }
    }

    return '..addProps(${context.sourceFor(value)})';
  }

  /// Migrate usages of tooltipContent/overlayTriggerProps to a wrapper OverlayTrigger.
  void migrateTooltipProps(FluentComponentUsage usage) {
    final tooltipContentProp = getFirstPropWithName(usage, 'tooltipContent');
    if (tooltipContentProp == null) return;

    final tooltipContentSource =
        context.sourceFor(tooltipContentProp.rightHandSide);
    yieldRemovePropPatch(tooltipContentProp);

    final overlayTriggerPropsProp =
        getFirstPropWithName(usage, 'overlayTriggerProps');
    final overlayTriggerCascadeToAdd = _cascadeFromMapPropValue(
        overlayTriggerPropsProp,
        destinationFactoryName: 'OverlayTrigger');
    if (overlayTriggerPropsProp != null) {
      yieldRemovePropPatch(overlayTriggerPropsProp);
    }

    final tooltipPropsProp = getFirstPropWithName(usage, 'tooltipProps');
    final tooltipCascadeToAdd = _cascadeFromMapPropValue(tooltipPropsProp,
        destinationFactoryName: 'Tooltip');
    if (tooltipPropsProp != null) {
      yieldRemovePropPatch(tooltipPropsProp);
    }

    final overlaySource =
        '${tooltipCascadeToAdd.isEmpty ? 'Tooltip()' : '(Tooltip()$tooltipCascadeToAdd)'}($tooltipContentSource)';

    yieldInsertionPatch(
        '(OverlayTrigger()\n'
        // Put this comment here instead of on OverlayTrigger since that might not format nicely
        '  ${lineComment('$fixmePrefix - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger')}'
        '..overlay2 = $overlaySource'
        '$overlayTriggerCascadeToAdd'
        ')(',
        usage.node.offset);
    yieldInsertionPatch(',)', usage.node.end);
  }

  /// Find icons that are the first/last children and also have siblings,
  /// and move them to startIcon/endIcon.
  ///
  /// For ambiguous cases, flag as needing manual verification.
  void migrateChildIcons(FluentComponentUsage usage) {
    // There can't be any icons if there aren't any children.
    // Also, being able to assume that children is non-empty simplifies below logic.
    if (usage.children.isEmpty) return;

    // If it's a single child or `noText = true`, no moving is needed.
    if (usage.children.length == 1 ||
        usage.cascadedProps.any((p) =>
            p.name.name == 'noText' &&
            p.rightHandSide.tryCast<BooleanLiteral>()?.value == true)) {
      return;
    }

    void handleEndChild(ComponentChild child, {required bool isFirst}) {
      final iconPropName = isFirst ? 'startIcon' : 'endIcon';

      void flagChild() => yieldChildFixmePatch(
          child,
          'Button child - manually verify that this child'
          ' is not an icon that should be moved to `$iconPropName`');

      // Don't try to handle non-expression (collection element) children.
      if (child is! ExpressionComponentChild) {
        flagChild();
        return;
      }

      final typeCategory = typeCategoryForReactNode(child.node);

      // Ignore primitive children since we know they can't be components.
      if (typeCategory == ReactNodeTypeCategory.primitive) return;

      // Flag for manual verification if children are of unknown types.
      if (typeCategory != ReactNodeTypeCategory.reactElement) {
        flagChild();
        return;
      }

      // Of the ReactElement children, if any aren't inline component usages
      // using top-level factories directly, flag for manual verification since we
      // can't tell for sure what component type they are.
      final childAsUsage = getComponentUsageFromExpression(child.node);
      if (childAsUsage == null ||
          childAsUsage.factoryTopLevelVariableElement == null) {
        flagChild();
        return;
      }

      if (usesWsdFactory(childAsUsage, 'Icon')) {
        yieldAddPropPatch(
            usage, '..$iconPropName = ${context.sourceFor(child.node)}');
        yieldRemoveChildPatch(child.node);
      }
    }

    final children = usage.children.toList();
    assert(children.length > 1);
    // Make sure we're operating on a non-filtered list of children here,
    // since we want to check the indexes of the children.
    handleEndChild(children.first, isFirst: true);
    handleEndChild(children.last, isFirst: false);
  }
}

const muiPrimaryColor = '$muiNs.ButtonColor.primary';

mixin ButtonDisplayPropsMigrator on ComponentUsageMigrator {
  void migrateButtonSkin(PropAssignment prop,
      {bool handleLinkVariants = false}) {
    final rhs = prop.rightHandSide;

    const muiOutlineVariant = '$muiNs.ButtonVariant.outlined';

    if (handleLinkVariants && isWsdStaticConstant(rhs, _linkButtonSkin)) {
      yieldRemovePropPatch(prop);
      return;
    }

    if (handleLinkVariants &&
        isWsdStaticConstant(rhs, _outlineLinkButtonSkin)) {
      yieldPropPatch(prop, newName: 'variant', newRhs: muiOutlineVariant);
      return;
    }

    if (isWsdStaticConstant(rhs, 'ButtonSkin.VANILLA')) {
      yieldPropPatch(prop,
          newName: 'color',
          newRhs: '$muiNs.ButtonColor.inherit',
          additionalCascadeSection: '..variant = $muiNs.ButtonVariant.text');
      return;
    }

    final colorFromWsdSkin = mapWsdConstant(rhs, const {
      'ButtonSkin.DANGER': '$muiNs.ButtonColor.error',
      'ButtonSkin.ALTERNATE': '$muiNs.ButtonColor.secondary',
      'ButtonSkin.LIGHT': '$muiNs.ButtonColor.wsdBtnLight',
      'ButtonSkin.WHITE': '$muiNs.ButtonColor.wsdBtnWhite',
      'ButtonSkin.INVERSE': '$muiNs.ButtonColor.wsdBtnInverse',
      'ButtonSkin.DEFAULT': '$muiNs.ButtonColor.inherit',
      'ButtonSkin.PRIMARY': muiPrimaryColor,
      'ButtonSkin.SUCCESS': '$muiNs.ButtonColor.success',
      'ButtonSkin.WARNING': '$muiNs.ButtonColor.warning',
    });
    if (colorFromWsdSkin != null) {
      yieldPropPatch(
        prop,
        newName: 'color',
        newRhs: colorFromWsdSkin,
      );
      return;
    }

    if (isWsdStaticConstant(rhs, 'ButtonSkin.OUTLINE_DEFAULT')) {
      yieldPropPatch(prop, newName: 'variant', newRhs: muiOutlineVariant);
      return;
    }

    final colorFromWsdOutlineSkin = mapWsdConstant(rhs, const {
      'ButtonSkin.OUTLINE_DANGER': '$muiNs.ButtonColor.error',
      'ButtonSkin.OUTLINE_ALTERNATE': '$muiNs.ButtonColor.secondary',
      'ButtonSkin.OUTLINE_LIGHT': '$muiNs.ButtonColor.wsdBtnLight',
      'ButtonSkin.OUTLINE_WHITE': '$muiNs.ButtonColor.wsdBtnWhite',
      'ButtonSkin.OUTLINE_INVERSE': '$muiNs.ButtonColor.wsdBtnInverse',
      'ButtonSkin.OUTLINE_PRIMARY': '$muiNs.ButtonColor.primary',
      'ButtonSkin.OUTLINE_SUCCESS': '$muiNs.ButtonColor.success',
      'ButtonSkin.OUTLINE_WARNING': '$muiNs.ButtonColor.warning',
    });
    if (colorFromWsdOutlineSkin != null) {
      yieldPropPatch(prop,
          newName: 'color',
          newRhs: colorFromWsdOutlineSkin,
          additionalCascadeSection: '..variant = $muiOutlineVariant');
      return;
    }

    // For other values, manual migration is safest.
    yieldPropManualMigratePatch(prop);
  }

  void migrateButtonSize(PropAssignment prop) {
    final sizeFromWsdSize = mapWsdConstant(prop.rightHandSide, const {
      'ButtonSize.XXSMALL': '$muiNs.ButtonSize.xxsmall',
      'ButtonSize.XSMALL': '$muiNs.ButtonSize.xsmall',
      'ButtonSize.SMALL': '$muiNs.ButtonSize.small',
      'ButtonSize.DEFAULT': '$muiNs.ButtonSize.medium',
      'ButtonSize.LARGE': '$muiNs.ButtonSize.large',
    });
    if (sizeFromWsdSize != null) {
      yieldPropPatch(prop, newRhs: sizeFromWsdSize);
      return;
    }

    // For other values, manual migration is safest.
    yieldPropManualMigratePatch(prop);
  }

  void migrateButtonType(PropAssignment prop) {
    final typeFromWsdType = mapWsdConstant(prop.rightHandSide, const {
      'ButtonType.BUTTON': _MuiButtonType.button,
      'ButtonType.SUBMIT': _MuiButtonType.submit,
      'ButtonType.RESET': _MuiButtonType.reset,
    });
    if (typeFromWsdType != null) {
      yieldPropPatch(prop, newRhs: typeFromWsdType);
      return;
    }

    // For other values, manual migration is safest.
    yieldPropManualMigratePatch(prop);
  }
}

abstract class _MuiButtonType {
  static const button = '$muiNs.ButtonType.button';
  static const submit = '$muiNs.ButtonType.submit';
  static const reset = '$muiNs.ButtonType.reset';
}
