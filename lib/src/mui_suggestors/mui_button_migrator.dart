import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/fluent_interface_util/cascade_read.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

import 'constants.dart';

// - Keep in mind: useful for components other than just button
//
// 1. Replace WSD component factory invocations with MUI component factory invocations
//
//
//     (Button() ... )('children')
//
//     (mui.Button() ... )('children')
//
// 2. Translate prop name and values from WSD to MUI
//
//     (Button()..skin = ButtonSkin.PRIMARY)(
//       (Button()..skin = ButtonSkin.PRIMARY)('children'),
//     )
//
//     (Button()
//       ..skin = ButtonSkin.PRIMARY
//     )('children')
//
//     final builder = Button()
//      ..skin = ButtonSkin.PRIMARY;
//
//     if (something) builder.skin = ButtonSkin.DANGER;
//     builder('children')
//
//     mui.Button()
//       ..color = mui.ButtonColor.primary
//
// 3. Add imports to RMUI, prefixed with mui (assuming any APIs accessed in other steps are also namespaced)
//
//     import 'package:react_material_ui/react_material_ui.dart' as mui;
//
// 4. (Potentially) Wrapping react_dom.render calls in a ThemeProvider
//
// 5. Remove unused imports for WSD component
//
//     - Resolved AST will allow us to detect these
//
// 6. Updates pubspec to include react_material_ui dependency with the correct version
//
// 7. Add RMUI script tag to relevant HTML files (examples, tests)
//
//     - Idea: find HTML files with react JS script tags and just add RMUI tags to those
//       https://sourcegraph.wk-dev.wdesk.org/search?q=packages/react/react%5Cw%2B.js&patternType=regexp
//          Lots of HTML (with a good portion of it generated or in templates), some Dart
//
// Question: how important is it that we flag tests containing components that have been updated? It could be pretty hard to tell what they are since tests don't usually render WSD components directly
//
//     - Can we just rely on test failures to identify these cases?

const _linkButtonSkin = 'ButtonSkin.LINK';
const _outlineLinkButtonSkin = 'ButtonSkin.OUTLINE_LINK';

const _linkButtonSkins = {
  _linkButtonSkin,
  _outlineLinkButtonSkin,
};

class MuiButtonMigrator
    with ClassSuggestor, ComponentUsageMigrator, ButtonDisplayPropsMigrator {
  // fixme how do we add imports in libraries? Collect files that need imports and add them after the fact?

  // fixme document decisions
  // Don't operate on unhandled cases; either they'll result in an analysis error or be fine (e.g., onClick)

  // FIXME need to figure out order to support cases that shouldn't get migrated...
  // E.g.:
  // - only migrate factory based on condition, then follow up in second pass and fix props on MUI button with analysis errors?
  // - collect which ones to migrate, do all of them in one pass?

  // fixme cocdemod feedback yieldPatch without end should be treated as insertion, not replace until end of file.

  // Consider dev workflow / CI / etc.

  // Execution order:
  // - Update pubspec.yaml
  //
  // - Update HTML and HTML templates
  //
  // - For full fluent usages
  //    - Check if usage has ignore comment; if so, short-circuit
  //    - Check if usage should be migrated (given factory and cascade); if not, short-circuit
  //    - Perform migration
  //        - Insert MUI library import if needed, remove WSD import if needed
  // FIXME execution order on this is off; we may want to do this on a second pass after the migrator runs
  //        - For known props that can't be perfectly converted, add a FIX-ME
  //        - Assume most other props (e.g., onClick, key, etc.) are fine
  //            - TODO Should we double-check ubiquitous/DOM/aria props?
  //            - TODO We should probably add a fixme to addProps/modifyProps
  //                - Other props maps
  //                - Forwarded props maps, potentially with props from WSD mixins
  //                  // TODO how to handle mixed in WSD props?
  // - For other usages
  //    - Check if usage has ignore comment; if so, short-circuit
  //    - Add FIX-ME
  //
  // - Wrap react_dom.render calls in ThemeProvider (inside ErrorBoundary if possible)
  //

  static bool hasLinkButtonSkin(FluentComponentUsage usage) => usage
      .cascadedProps
      .any((p) => p.name.name == 'skin' && isLinkButtonSkin(p.rightHandSide));

  static bool isLinkButtonSkin(Expression expr) =>
      _linkButtonSkins.any((linkSkin) => isWsdStaticConstant(expr, linkSkin));

  @override
  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage) {
    if (usesWsdFactory(usage, 'Button')) {
      return MigrationDecision.shouldMigrate;
    }

    if (usesWsdFactory(usage, 'FormSubmitInput') ||
        usesWsdFactory(usage, 'FormResetInput')) {
      return hasLinkButtonSkin(usage)
          ? MigrationDecision.needsManualIntervention
          : MigrationDecision.shouldMigrate;
    }

    return MigrationDecision.notApplicable;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final newFactory =
        hasLinkButtonSkin(usage) ? '$muiNs.LinkButton' : '$muiNs.Button';
    yieldPatchOverNode(newFactory, usage.factory!);

    var propsClassHasHitareaMixin = false;
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

      propsClassHasHitareaMixin = usesWsdV1Factory(usage);
    } else if (usesWsdFactory(usage, 'FormResetInput')) {
      yieldAddPropPatch(usage, "..type = 'reset'",
          placement: NewPropPlacement.end);

      propsClassHasHitareaMixin = usesWsdV1Factory(usage);
    }

    migratePropsByName(usage, migratorsByName: {
      // Simple replacements.
      'isActive': (p) => yieldPropPatch(p, newName: 'aria.pressed'),
      'isBlock': (p) => yieldPropPatch(p, newName: 'fullWidth'),
      'isDisabled': (p) => yieldPropPatch(p, newName: 'disabled'),
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

      void flagChild() => yieldInsertionPatch(
          lineComment('FIXME(mui_migration) - Button child'
              ' - manually verify that this child is not an icon that should be moved to `$iconPropName`'),
          child.node.offset);

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
      // using factories directly, flag for manual verification since we
      // can't tell for sure what component type they are.
      final childAsUsage = getComponentUsageFromExpression(child.node);
      if (childAsUsage == null || childAsUsage.factory == null) {
        flagChild();
        return;
      }

      // Handle any icon children and move them.
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
