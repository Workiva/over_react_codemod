// import 'dart:async';
//
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

// import 'package:analyzer/source/source_range.dart';
// import 'package:analyzer_plugin/utilities/range_factory.dart';
// import 'package:meta/meta.dart';
// import 'package:over_react_analyzer_plugin/src/component_usage.dart';
// import 'package:over_react_analyzer_plugin/src/util/util.dart';
//
// import 'cascade_edits.dart';

extension UsageCascades on FluentComponentUsage {
  Iterable<Expression> get cascadeSections =>
      cascadeExpression?.cascadeSections ?? const [];

  /// Returns an iterable of all cascaded prop assignments in this usage.
  ///
  /// See also: [cascadedMethodInvocations]
  Iterable<PropAssignment> get cascadedProps => cascadeSections
      .whereType<AssignmentExpression>()
      .where((assignment) => assignment.leftHandSide is PropertyAccess)
      .map((assignment) => PropAssignment(assignment));

  // fixme tests for how `..dom.id = ''` works
  Iterable<PropAccess> get cascadedGetters =>
      cascadeSections.whereType<PropertyAccess>().map((p) => PropAccess(p));

  Iterable<IndexPropAssignment> get cascadedIndexAssignments => cascadeSections
      .whereType<AssignmentExpression>()
      .where((assignment) => assignment.leftHandSide is IndexExpression)
      .map((assignment) => IndexPropAssignment(assignment));

  /// Returns an iterable of all cascaded method calls in this usage.
  Iterable<BuilderMethodInvocation> get cascadedMethodInvocations =>
      cascadeSections
          .whereType<MethodInvocation>()
          .map((methodInvocation) => BuilderMethodInvocation(methodInvocation));

  List<BuilderMemberAccess> get cascadedMembers => [
        ...cascadedProps,
        ...cascadedGetters,
        ...cascadedIndexAssignments,
        ...cascadedMethodInvocations,
      ]
        // Order them in the order they appear by sorting based on the offset.
        ..sort((a, b) => a.node.offset.compareTo(b.node.offset));

// Iterable<BuilderMemberAccess?> get cascadedMembers sync* {
//   for (final section in cascadeSections) {
//     if (section is AssignmentExpression) {
//       if (section.leftHandSide is PropertyAccess) {
//         yield PropAssignment(section);
//       } else if (section.leftHandSide is IndexExpression) {
//         yield IndexPropAssignment(section);
//       } else {
//         // unhandled ccase
//         yield null;
//       }
//     } else if (section is MethodInvocation) {
//       yield BuilderMethodInvocation(section);
//     } else {
//       // unhandled ccase
//       yield null;
//     }
//   }
// }
}

//
// class PropAssignment {
//   /// The cascaded assignment expression that backs this assignment.
//   final AssignmentExpression assignment;
//
//   PropAssignment(this.assignment) : assert(assignment.leftHandSide is PropertyAccess);
//
//   /// The property access representing the left hand side of this assignment.
//   PropertyAccess get leftHandSide => assignment.leftHandSide as PropertyAccess;
//
//   /// The expression for the right hand side of this assignment.
//   Expression get rightHandSide => assignment.rightHandSide;
//
//   /// The name of the prop being assigned.
//   Identifier get name => leftHandSide.propertyName;
//
//   /// The "target" of the [name].
//   ///
//   /// For example, the value of `targetName.name` in the expression below is "aria":
//   ///
//   /// ```dart
//   /// ..aria.label = 'foo'
//   /// ```
//   Identifier get targetName => leftHandSide.target?.tryCast<PropertyAccess>()?.propertyName;
//
//   /// A range that can be used in a `builder.addDeletion` call to remove this prop.
//   ///
//   /// Includes the space between the previous token and the start of this assignment, so that
//   /// the entire prop line is removed.
//   ///
//   /// __Note: prefer using [removeProp] instead of using this directly to perform removals__
//   @protected
//   SourceRange get rangeForRemoval => range.endEnd(assignment.beginToken.previous, assignment);
// }
//
// // TODO remove once all in-flight PRs that might be consuming this are merged
// @Deprecated('Use FluentComponentUsage.cascadedProps instead')
// void forEachCascadedProp(FluentComponentUsage usage, void Function(PropertyAccess lhs, Expression rhs) f) {
//   for (final prop in usage.cascadedProps) {
//     f(prop.leftHandSide, prop.rightHandSide);
//   }
// }
//
// // TODO remove once all in-flight PRs that might be consuming this are merged
// @Deprecated('Use FluentComponentUsage.cascadedProps instead')
// Future<void> forEachCascadedPropAsync(
//     FluentComponentUsage usage, FutureOr<void> Function(PropertyAccess lhs, Expression rhs) f) async {
//   for (final prop in usage.cascadedProps) {
//     await f(prop.leftHandSide, prop.rightHandSide);
//   }
// }
//
// // TODO remove once all in-flight PRs that might be consuming this are merged
// @Deprecated('Use FluentComponentUsage.cascadedMethods instead')
// void forEachCascadedMethod(
//     FluentComponentUsage usage, void Function(SimpleIdentifier methodIdentifier, ArgumentList args) f) {
//   for (final invocation in usage.cascadedMethodInvocations) {
//     f(invocation.methodName, invocation.argumentList);
//   }
// }
//
// // TODO remove once all in-flight PRs that might be consuming this are merged
// @Deprecated('Use FluentComponentUsage.cascadedMethods instead')
// Future<void> forEachCascadedMethodAsync(
//     FluentComponentUsage usage, FutureOr<void> Function(SimpleIdentifier methodIdentifier, ArgumentList args) f) async {
//   for (final invocation in usage.cascadedMethodInvocations) {
//     await f(invocation.methodName, invocation.argumentList);
//   }
// }
