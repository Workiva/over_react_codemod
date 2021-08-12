import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/element_type_helpers.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

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
//
// Question: how important is it that we flag tests containing components that have been updated? It could be pretty hard to tell what they are since tests don't usually render WSD components directly
//
//     - Can we just rely on test failures to identify these cases?

class MuiButtonMigrator extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  static const muiNamespace = 'mui';

  @override
  bool shouldResolveAst(FileContext context) => true;

  // fixme how do we add imports in libraries? Collect files that need imports and add them after the fact?

  // fixme document decisions
  // Don't operate on unhandled cases; either they'll result in an analysis error or be fine (e.g., onClick)

  // FIXME need to figure out order to support cases that shouldn't get migrated...
  // E.g.:
  // - only migrate factory based on condition, then follow up in second pass and fix props on MUI button with analysis errors?
  // - collect which ones to migrate, do all of them in one pass?

  // fixme cocdemod feedback yieldPatch without end should be treated as insertion, not replace until end of file.

  // yieldPatch utilities
  // replace prop name
  // replace prop value
  // remove prop
  // add new prop (if cascaded and possible, otherwise add comment)
  // add comment

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // final lhs = node.leftHandSide;
    //
    // late Expression target;
    // late Identifier prop;
    // if (lhs is PrefixedIdentifier) {
    //   target = lhs.prefix;
    //   prop = lhs.identifier;
    // } else if (lhs is PropertyAccess) {
    //   target = lhs.realTarget;
    //   prop = lhs.propertyName;
    // } else {
    //   throw UnhandledCaseError();
    // }
    final propAssignment = getPropAssignment(node);
    if (propAssignment == null) return;
    if (propAssignment.target.staticType?.element
            ?.isOrIsSubtypeOfTypeFromPackage('ButtonProps', 'web_skin_dart') ??
        false) {
      final propName = propAssignment.name.name;

      switch (propName) {
        case 'isActive':
          if (propAssignment.isInCascade) {
            final rhsSource = sourceFor(propAssignment.rightHandSide);
            yieldPatchOverNode(
                '  ..aria.selected = ${rhsSource}'
                '\n  ..aria.expanded = ${rhsSource}',
                node);
          } else {
            yieldPatch(
                ' /* FIXME mui-migration replace with aria.selected/aria.expanded */',
                node.end);
          }
          break;

        case 'isCallout':
          yieldPatch(' /* FIXME mui-migration handle this case */', node.end);
          break;

        // fixme pullRight/pullLeft

        // fixme notext
        //fixme tooltipContent/overlayTriggerProps
        // fixme REFS

        // fixme type checks?

        // fixme size/skin what about prefixed imports to WSD? should we even worry about those

        // fixme prop values inside ternaries in props? Should we be using AST for that instead of matching whole expression? probably not for all cases since the migration would be more complex
        // will we get issues if implicit casts aren't enabled? e.g. `..color = condition ? ButtonSkin.PRIMARY : somethingElse`, since it's `dynamic`?

        case 'size':
          const valueMappings = {
            'ButtonSize.XXSMALL': 'mui.ButtonSize.xxsmall',
            'ButtonSize.XSMALL': 'mui.ButtonSize.xsmall',
            'ButtonSize.SMALL': 'mui.ButtonSize.small',
            'ButtonSize.DEFAULT': 'mui.ButtonSize.default',
            'ButtonSize.LARGE': 'mui.ButtonSize.large',
          };

          final rhsSourceApproximation =
              propAssignment.rightHandSide.toSource();
          final newValue = valueMappings[rhsSourceApproximation];
          if (newValue != null) {
            yieldPatchOverNode(newValue, propAssignment.rightHandSide);
          }
          break;

        case 'skin':
          const colorMappings = {
            // Different
            'ButtonSkin.DANGER': 'mui.ButtonColor.error',
            'ButtonSkin.ALTERNATE': 'mui.ButtonColor.secondary',
            'ButtonSkin.LIGHT': 'mui.ButtonColor.wsdBtnLight',
            'ButtonSkin.WHITE': 'mui.ButtonColor.wsdBtnWhite',
            'ButtonSkin.INVERSE': 'mui.ButtonColor.wsdBtnInverse',
            'ButtonSkin.DEFAULT': 'mui.ButtonColor.default_',
            // Lowercase
            'ButtonSkin.PRIMARY': 'mui.ButtonColor.primary',
            'ButtonSkin.SUCCESS': 'mui.ButtonColor.success',
            'ButtonSkin.WARNING': 'mui.ButtonColor.warning',
            // FIXME need to check if a button can be translated based on this prop value?
            // 'ButtonSkin.LINK': 'ButtonColor.link', Use the LinkButton component (Not yet available)
          };

          final rhsSourceApproximation =
              propAssignment.rightHandSide.toSource();

          final outlinePattern = RegExp(r'^(ButtonSkin\.)OUTLINE_(\w+)');
          final isOutline = outlinePattern.hasMatch(rhsSourceApproximation);
          final rhsSourceWithoutOutline =
              rhsSourceApproximation.replaceFirstMapped(
                  outlinePattern, (match) => '${match[1]!}${match[2]!}');

          if (rhsSourceWithoutOutline == 'ButtonSkin.VANILLA') {
            yieldPatch(
                ' /* FIXME mui-migration convert this component to ButtonBase */',
                node.end,
                node.end);
          } else {
            final colorMapping = colorMappings[rhsSourceWithoutOutline];
            if (colorMapping != null) {
              yieldPatchOverNode('color', propAssignment.name);
              if (isOutline) {
                yieldPatchOverNode(
                    '${colorMapping} \n  ..variant = mui.ButtonVariant.outlined',
                    propAssignment.rightHandSide);
              } else {
                yieldPatchOverNode(colorMapping, propAssignment.rightHandSide);
              }
            }
          }
          break;

        default:
          const simpleRenames = {
            'isDisabled': 'disabled',
            'isFlat': 'disableElevation',
            'isBlock': 'fullWidth',
            'role': 'dom.role',
          };
          final simpleRename = simpleRenames[propName];
          if (simpleRename != null) {
            yieldPatchOverNode(simpleRename, propAssignment.name);
          }
          break;
      }
    }
  }

  @override
  void visitIdentifier(Identifier node) {
    final staticElement = node.staticElement;
    // TODO do we need to handle both? add comment here on why you're handling both

    final name = staticElement.tryCast<PropertyAccessorElement>()?.name ??
        staticElement.tryCast<FieldElement>()?.name;

    if (name == 'Button' && staticElement!.isDeclaredInWsd) {
      yieldPatch('mui.Button', node.offset, node.end);
    }
  }

  String sourceFor(SyntacticEntity entity) {
    return context.sourceText.substring(entity.offset, entity.end);
  }

  void yieldPatchOverNode(String updatedText, SyntacticEntity entityToReplace) {
    yieldPatch(updatedText, entityToReplace.offset, entityToReplace.end);
  }

// @override
// void visitInvocationExpression(InvocationExpression node) {
//   final returnType = node.staticType;
//   if (returnType is! InterfaceType) return;
//
//   final returnTypeInheritsFromUiProps = returnType.element.allSupertypes
//       .whereType<InterfaceType>()
//       .map((e) => e.element)
//       .any((element) =>
//           element.name == 'UiProps' && element.isDeclaredInOverReact);
//   if (!returnTypeInheritsFromUiProps) return;
//
//   // InvocationExpression: `someRandomMethod()`
//   // InvocationExpression: `Button()`
//   // InvocationExpression: `isComponentOfType(Button)`
//   // InvocationExpression: `(renderAButton ? Button : Dom.div)()`
//   // FIXME make sure we handle `wsd.Button()` as well as Button
//
//   final function = node is MethodInvocation ? node.methodName : node.function;
//
//   if (function is Identifier) {
//     final staticElement = function.staticElement;
//     // TODO do we need to handle both? add comment here on why you're handling both
//
//     final name = staticElement.tryCast<PropertyAccessorElement>()?.name ??
//         staticElement.tryCast<FieldElement>()?.name;
//
//     if (name == 'Button' && staticElement!.isDeclaredInWsd) {
//       // do stuff!
//       yieldPatch('mui.Button', node.function.offset, node.function.end);
//     }
//   }
// }
}

class UnhandledCaseError extends Error {}
//
// class Foo {
//   var bar;
// }
//
// main() {
//   Foo foo = Foo(XZ);
//
//   // AssignmentExpressionImpl PrefixedIdentifierImpl
//   foo.bar = '';
//   // AssignmentExpressionImpl PropertyAccessImpl
//   foo?.bar = '';
//   // CascadeExpressionImpl AssignmentExpressionImpl PropertyAccessImpl
//   foo..bar = '';
// }

extension _TryCast<T> on T {
  S? tryCast<S extends T>() {
    final self = this;
    return self is S ? self : null;
  }
}

// package:web_skin_dart/....

extension on Element {
  bool get isDeclaredInOverReact => isDeclaredInPackage('over_react');

  bool get isDeclaredInWsd => isDeclaredInPackage('web_skin_dart');
}
