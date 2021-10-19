import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

import '../constants.dart';

const _linkButtonSkin = 'ButtonSkin.LINK';
const _outlineLinkButtonSkin = 'ButtonSkin.OUTLINE_LINK';

const _linkButtonSkins = {
  _linkButtonSkin,
  _outlineLinkButtonSkin,
};

class MuiButtonMigrator
    with ClassSuggestor, ComponentUsageMigrator, ButtonDisplayPropsMigrator {
  static bool hasLinkButtonSkin(FluentComponentUsage usage) => usage
      .cascadedProps
      .any((p) => p.name.name == 'skin' && isLinkButtonSkin(p.rightHandSide));

  static bool isLinkButtonSkin(Expression expr) =>
      _linkButtonSkins.any((linkSkin) => isWsdStaticConstant(expr, linkSkin));

  @override
  ShouldMigrateDecision shouldMigrateUsage(FluentComponentUsage usage) {
    // Don't migrate WSD toolbar components (for now)
    if (usesWsdToolbarFactory(usage)) {
      return ShouldMigrateDecision.no;
    }

    if (usesWsdFactory(usage, 'Button')) {
      return ShouldMigrateDecision.yes;
    }

    if (usesWsdFactory(usage, 'FormSubmitInput') ||
        usesWsdFactory(usage, 'FormResetInput')) {
      return hasLinkButtonSkin(usage)
          ? ShouldMigrateDecision.needsManualIntervention
          : ShouldMigrateDecision.yes;
    }

    return ShouldMigrateDecision.no;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final newFactory =
        hasLinkButtonSkin(usage) ? '$muiNs.LinkButton' : '$muiNs.Button';
    yieldPatchOverNode(newFactory, usage.factory!);

    bool propsClassHasHitareaMixin;
    if (usesWsdFactory(usage, 'FormSubmitInput')) {
      // Avoid adding two props separately at the same time when there are no
      // no parens around the builder, which yields the following diff:
      // - FormSubmitInput()('Create Item'),
      // + ((mui.Button()..color = mui.ButtonColor.primary..type = 'submit'))('Create Item')
      // Normally this isn't a big deal and doesn't happen often, but for this
      // factory it's really common to not have any parens/props.

      final colorPatch = '..color = $muiPrimaryColor';
      const typePatch = "..type = 'submit'";

      if (usage.node.function is! ParenthesizedExpression) {
        yieldAddPropPatch(usage, colorPatch + typePatch);
      } else {
        yieldAddPropPatch(usage, colorPatch, placement: NewPropPlacement.start);
        yieldAddPropPatch(usage, typePatch, placement: NewPropPlacement.end);
      }

      propsClassHasHitareaMixin =
          wsdComponentVersionForFactory(usage) != WsdComponentVersion.v1;
    } else if (usesWsdFactory(usage, 'FormResetInput')) {
      yieldAddPropPatch(usage, "..type = 'reset'",
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
      'isDisabled': (p) {
        yieldPropFixmePatch(p,
            'if this button needs to show a tooltip/overlay when disabled, add a wrapper element');
        yieldPropPatch(p, newName: 'disabled');
      },
      'isFlat': (p) => yieldPropPatch(p, newName: 'disableElevation'),

      // Lengthier migration code; split out into methods.
      'skin': (p) => migrateButtonSkin(p, handleLinkVariants: true),
      'size': migrateButtonSize,

      // Props that always need manual intervention.
      // TODO for these point to migration guide or hint at what to do
      'isCallout': yieldPropManualMigratePatch,
      'pullRight': yieldPropManualMigratePatch,

      // Only attempt to migrate these props if they're declared on the props class
      // (since we'll get errors otherwise).
      if (propsClassHasHitareaMixin) ...{
        'role': (p) => yieldPropPatch(p, newName: 'dom.role'),
        'target': (p) => yieldPropPatch(p, newName: 'dom.target'),
        // TODO follow up on how we want to handle this; maybe add tooltipContent?
        'overlayTriggerProps': yieldPropManualMigratePatch,
        'tooltipContent': yieldPropManualMigratePatch,
      }
    });

    migrateChildIcons(usage);

    // It's almost impossible to tell with certainty which components a component
    // is nested within, so instead we'll just use the presence of that component
    // name in the file as a heuristic, and flag migrated buttons to be
    // manually checked.
    if (context.sourceText.contains('DialogFooter')) {
      flagUsageFixmeComment(
          usage,
          "check whether this button is nested inside a DialogFooter."
          " If so, wrap it in a $muiNs.ButtonToolbar with `..sx = {'float': 'right'}`.");
    }
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

      // Ignore primitive children since we know they can't be components.
      if (child.childType == SimpleChildType.primitive) return;

      // Flag for manual verification if children are of unknown types.
      if (child.childType != SimpleChildType.reactElement) {
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
      // todo play around with removing props and adding them vs modifying them
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

    // fixme make it obvious why we're calling this everywhere without having to copy-paste a huge comment every time.
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

    yieldPropManualMigratePatch(prop);
  }
}

// fixme document decisions / guidelines
// - Don't operate on unhandled cases; either they'll result in an analysis error or be fine (e.g., onClick)
// - When in doubt, flag for manual verification; even if you were able to migrate
// - Watch out for dynamic casts
// - Be conservative when computing patch ranges; this helps prevent conflicting ("overlapping") patches,
//   especially when there are multiple places in the code making replacements.
// - Don't use toSource()
// - Don't operate on unhandled props cases; either they'll result in an analysis error or be fine (e.g., onClick)
//    - Assume most other props (e.g., onClick, key, etc.) are fine
//        - fixme Should we double-check ubiquitous/DOM/aria props?
//        - fixme how to handle mixed in WSD props?
