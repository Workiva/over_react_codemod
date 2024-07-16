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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_prop_info/prop_requiredness_aggregated.sg.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

class RequiredPropsMigrator extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  PropRequirednessRecommender _propRequirednessRecommender;

  RequiredPropsMigrator(this._propRequirednessRecommender);

  @override
  Future<void> generatePatches() async {
    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.accept(this);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);

    final fieldDeclaration = node.parentFieldDeclaration;
    if (fieldDeclaration == null) return;
    if (fieldDeclaration.isStatic) return;
    if (fieldDeclaration.fields.isConst) return;

    final element = node.declaredElement;
    if (element is! FieldElement) return;

    final type = fieldDeclaration.fields.type;
    if (type != null &&
        (requiredHintAlreadyExists(type) ||
            nullableHintAlreadyExists(type) ||
            nonNullableHintAlreadyExists(type))) {
      return;
    }

    final recommendation =
        _propRequirednessRecommender.getRecommendation(element);

    switch (recommendation) {
      case PropRequirednessRecommendation.noData:
        break;
      case PropRequirednessRecommendation.required:
        // Don't unnecessarily annotate it as non-nullable;
        // let the migrator tool do that.
        final offset =
            fieldDeclaration.firstTokenAfterCommentAndMetadata.offset;
        yieldPatch('$lateHint ', offset, offset);

        break;
      case PropRequirednessRecommendation.optional:
        if (type != null) {
          yieldPatch(nullableHint, type.end, type.end);
        }
        break;
    }
  }
}

class PropRequirednessRecommender {
  final PropRequirednessResults _propRequirednessResults;

  final num requirednessThreshold;

  PropRequirednessRecommender(this._propRequirednessResults,
      {required this.requirednessThreshold}) {
    if (!(requirednessThreshold >= 0 && requirednessThreshold <= 1)) {
      throw ArgumentError.value(requirednessThreshold, 'requirednessThreshold',
          'must be between 0 and 1 (inclusive)');
    }
  }

  PropRequirednessRecommendation getRecommendation(FieldElement propField) {
    final propName = propField.name;
    final propsElement = propField.enclosingElement;
    final packageName = getPackageName(propsElement.source!.uri);
    final propsId = uniqueElementId(propsElement);

    final mixinResults = _propRequirednessResults
        .mixinResultsByIdByPackage[packageName]?[propsId];
    if (mixinResults == null) return PropRequirednessRecommendation.noData;

    final propResults = mixinResults.propResultsByName[propName];
    if (propResults == null) return PropRequirednessRecommendation.noData;

    // FIXME need publicness data.
    // final isPublic = _propRequirednessResults.

    return propResults.totalRate >= requirednessThreshold
        ? PropRequirednessRecommendation.required
        : PropRequirednessRecommendation.optional;
  }
}

enum PropRequirednessRecommendation {
  noData,
  required,
  optional,
}

String? getPackageName(Uri uri) {
  if (uri.scheme == 'package') return uri.pathSegments[0];
  return null;
}

String uniqueElementId(Element element) {
  // Use element.location so that we consolidate elements across different contexts
  final location = element.location;
  if (location != null) {
    // Remove duplicate package URI
    final components = {...location.components}.toList();
    // Move the package to the end so that the class shows up first, which is easier to read.
    final pathIndex = components.indexWhere((c) => c.startsWith('package:'));
    final path = pathIndex == -1 ? null : components.removeAt(pathIndex);
    return [components.join(';'), if (path != null) path].join(' - ');
  }

  return 'root:${element.session?.analysisContext.contextRoot},id:${element.id},${element.source?.uri},${element.name}';
}
