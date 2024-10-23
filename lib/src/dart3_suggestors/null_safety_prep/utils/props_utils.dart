import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

/// Returns a list of props from [cascade].
Iterable<PropAssignment> getCascadedProps(CascadeExpression cascade) {
  return cascade.cascadeSections
      .whereType<AssignmentExpression>()
      .where((assignment) => assignment.leftHandSide is PropertyAccess)
      .map((assignment) => PropAssignment(assignment))
      .where((prop) => prop.node.writeElement?.displayName != null);
}
