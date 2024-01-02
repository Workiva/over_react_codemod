// Copyright 2024 Workiva Inc.
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

import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:logging/logging.dart';

final _log = Logger('CallbackrefHintSuggestor');

// todo update comment
/// Suggestor that performs all the updates needed to migrate from the react_material_ui package
/// to the unify_ui package:
///
/// - Rename specific components and objects
/// - Update WSD ButtonColor usages
/// - Rename import namespaces 'mui' => 'unify'
/// - Add fix me comments for manual checks
///
/// Also see migration guide: https://github.com/Workiva/react_material_ui/tree/master/react_material_ui#how-to-migrate-from-reactmaterialui-to-unifyui
class CallbackRefHintSuggestor extends ComponentUsageMigrator {
  @override
  bool shouldMigrateUsage(_) => true;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    for(final prop in usage.cascadedProps) {
      if(prop.name.name == 'ref') {
        final rhs = prop.rightHandSide;
        if(rhs is FunctionExpression) {
          // todo add fixme if there are more than one params

          // Add nullability hint to parameter if typed.
          final param = rhs.parameters?.parameters.first;
          if(param is SimpleFormalParameter) {
            final type = param.type;
          if(type != null) {
              yieldPatch(nullabilityHint, type.end, type.end);
            }
          }

          // Add nullability hint to any casts in the body of the callback ref.
          final castVisitor = RefCastingVisitor();
          rhs.body.visitChildren(castVisitor);
          for(final location in castVisitor.locationsNeedingHints) {
            yieldPatch(nullabilityHint, location, location);
          }
        }
      }
    }
  }

  @override
  String get fixmePrefix => 'FIXME(null_safety_migration)';

  @override
  // Override so that no flags are added.
  void flagCommon(_) {}
}

// todo add doc comment
class RefCastingVisitor extends RecursiveAstVisitor<void> with AstVisitingSuggestor{

  final locationsNeedingHints = [];
  RefCastingVisitor();

  @override
  void visitAsExpression(AsExpression node) {
    super.visitAsExpression(node);
    // todo check here to match ref type to be sure
    locationsNeedingHints.add(node.type.end);
  }
}

const nullabilityHint = '/*?*/';
