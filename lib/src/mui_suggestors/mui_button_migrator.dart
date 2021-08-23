import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/fluent_interface_util/cascade_read.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

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

const muiNs = 'mui';

class MuiButtonMigrator extends Object
    with ClassSuggestor, ComponentUsageMigrator {
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

  final bool isLinkButtonAvailable;

  MuiButtonMigrator({this.isLinkButtonAvailable = false});

  static const linkButtonSkin = 'ButtonSkin.LINK';
  static const outlineLinkButtonSkin = 'ButtonSkin.OUTLINE_LINK';

  static const linkButtonSkins = {
    linkButtonSkin,
    outlineLinkButtonSkin,
  };

  static bool hasLinkButtonSkin(FluentComponentUsage usage) =>
      usage.cascadedProps
          .where((p) => p.name.name == 'skin')
          .map((p) => p.rightHandSide)
          .any(isLinkButtonSkin);

  static bool isLinkButtonSkin(Expression expr) =>
      linkButtonSkins.any((linkSkin) => isWsdStaticConstant(expr, linkSkin));

  @override
  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage) {
    if (usesWsdFactory(usage, 'Button')) {
      if (!isLinkButtonAvailable && hasLinkButtonSkin(usage)) {
        // We'll handle these once the LinkButton component is available.
        return MigrationDecision.notApplicable;
      }

      return MigrationDecision.shouldMigrate;
    }

    return MigrationDecision.notApplicable;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    bool shouldBeLinkButton = hasLinkButtonSkin(usage);
    assert(!shouldBeLinkButton || isLinkButtonAvailable);

    final newFactory =
        shouldBeLinkButton ? '$muiNs.LinkButton' : '$muiNs.Button';
    yieldPatchOverNode(newFactory, usage.factory!);

    migratePropsByName(usage, migratorsByName: {
      // Simple replacements.
      'isBlock': (p) => yieldPropPatch(p, newName: 'fullWidth'),
      'isDisabled': (p) => yieldPropPatch(p, newName: 'disabled'),
      'isFlat': (p) => yieldPropPatch(p, newName: 'disableElevation'),
      'role': (p) => yieldPropPatch(p, newName: 'dom.role'),
      'target': (p) => yieldPropPatch(p, newName: 'dom.target'),

      // Lengthier migration code; split out into methods.
      'isActive': _migrateIsActive,
      'skin': _migrateSkin,
      'size': _migrateSize,

      // Props that always need manual intervention.
      'isCallout': yieldPropManualMigratePatch,
      'overlayTriggerProps': yieldPropManualMigratePatch,
      'pullRight': yieldPropManualMigratePatch,
      'tooltipContent': yieldPropManualMigratePatch,
    });
  }

  void _migrateIsActive(PropAssignment prop) {
    // fixme ensure EOL comments are handled properly
    final rhsSource = context.sourceFor(prop.rightHandSide);
    yieldPatchOverNode(
        '..aria.selected = ${rhsSource}'
        '\n  ..aria.expanded = ${rhsSource}',
        prop.assignment);
  }

  void _migrateSkin(PropAssignment prop) {
    final rhs = prop.rightHandSide;

    const muiOutlineVariant = '$muiNs.ButtonVariant.outlined';

    if (isWsdStaticConstant(rhs, linkButtonSkin)) {
      yieldRemovePropPatch(prop);
      return;
    }

    if (isWsdStaticConstant(rhs, outlineLinkButtonSkin)) {
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

    const skinToColor = {
      'ButtonSkin.DANGER': '$muiNs.ButtonColor.error',
      'ButtonSkin.ALTERNATE': '$muiNs.ButtonColor.secondary',
      'ButtonSkin.LIGHT': '$muiNs.ButtonColor.wsdBtnLight',
      'ButtonSkin.WHITE': '$muiNs.ButtonColor.wsdBtnWhite',
      'ButtonSkin.INVERSE': '$muiNs.ButtonColor.wsdBtnInverse',
      'ButtonSkin.DEFAULT': '$muiNs.ButtonColor.inherit',
      'ButtonSkin.PRIMARY': '$muiNs.ButtonColor.primary',
      'ButtonSkin.SUCCESS': '$muiNs.ButtonColor.success',
      'ButtonSkin.WARNING': '$muiNs.ButtonColor.warning',
    };
    final colorFromSkin = skinToColor
        .firstValueWhereOrNull((skin, _) => isWsdStaticConstant(rhs, skin));
    if (colorFromSkin != null) {
      yieldPropPatch(
        prop,
        newName: 'color',
        newRhs: colorFromSkin,
      );
      return;
    }

    if (isWsdStaticConstant(rhs, 'ButtonSkin.OUTLINE_DEFAULT')) {
      yieldPropPatch(prop, newName: 'variant', newRhs: muiOutlineVariant);
      return;
    }

    const outlineSkinToColor = {
      'ButtonSkin.OUTLINE_DANGER': '$muiNs.ButtonColor.error',
      'ButtonSkin.OUTLINE_ALTERNATE': '$muiNs.ButtonColor.secondary',
      'ButtonSkin.OUTLINE_LIGHT': '$muiNs.ButtonColor.wsdBtnLight',
      'ButtonSkin.OUTLINE_WHITE': '$muiNs.ButtonColor.wsdBtnWhite',
      'ButtonSkin.OUTLINE_INVERSE': '$muiNs.ButtonColor.wsdBtnInverse',
      'ButtonSkin.OUTLINE_PRIMARY': '$muiNs.ButtonColor.primary',
      'ButtonSkin.OUTLINE_SUCCESS': '$muiNs.ButtonColor.success',
      'ButtonSkin.OUTLINE_WARNING': '$muiNs.ButtonColor.warning',
    };
    final colorFromOutlineSkin = outlineSkinToColor
        .firstValueWhereOrNull((skin, _) => isWsdStaticConstant(rhs, skin));
    if (colorFromOutlineSkin != null) {
      yieldPropPatch(prop,
          newName: 'color',
          newRhs: colorFromOutlineSkin,
          additionalCascadeSection: '..variant = $muiOutlineVariant');
      return;
    }

    // fixme make it obvious why we're calling this everywhere without having to copy-paste a huge comment every time.
    yieldPropManualMigratePatch(prop);
  }

  void _migrateSize(PropAssignment prop) {
    const sizeToNewSize = {
      'ButtonSize.XXSMALL': '$muiNs.ButtonSize.xxsmall',
      'ButtonSize.XSMALL': '$muiNs.ButtonSize.xsmall',
      'ButtonSize.SMALL': '$muiNs.ButtonSize.small',
      'ButtonSize.DEFAULT': '$muiNs.ButtonSize.medium',
      'ButtonSize.LARGE': '$muiNs.ButtonSize.large',
    };

    final newSize = sizeToNewSize.firstValueWhereOrNull(
        (size, _) => isWsdStaticConstant(prop.rightHandSide, size));
    if (newSize != null) {
      yieldPropPatch(prop, newRhs: newSize);
      return;
    }

    yieldPropManualMigratePatch(prop);
  }
}
