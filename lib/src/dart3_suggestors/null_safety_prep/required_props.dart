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
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_prop_info/aggregated_data.sg.dart';
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
  void visitMixinDeclaration(MixinDeclaration node) {
    super.visitMixinDeclaration(node);
    handleClassOrMixinElement(node, node.declaredElement);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    handleClassOrMixinElement(node, node.declaredElement);
  }

  void handleClassOrMixinElement(
      NamedCompilationUnitMember node, InterfaceElement? element) {
    if (element == null) return null;

    // Add a comment to let consumers know that we didn't have good enough data
    // to make requiredness decision.
    final skipReason =
        _propRequirednessRecommender.getMixinSkipRateReasonForElement(element);
    if (skipReason != null) {
      String formatAsPercent(num number) =>
          '${(number * 100).toStringAsFixed(0)}%';

      final skipRatePercent = formatAsPercent(skipReason.skipRate);
      final maxAllowedSkipRatePercent =
          formatAsPercent(skipReason.maxAllowedSkipRate);

      final commentContents =
          "TODO orcm.required_props: This codemod couldn't reliably determine requiredness for these props"
          "\n because $skipRatePercent of usages of components with these props"
          " (> max allowed $maxAllowedSkipRatePercent for ${skipReason.isPublic ? 'public' : 'private'} props)"
          "\n either contained forwarded props or were otherwise too dynamic to analyze."
          "\n It may be possible to upgrade some from optional to required, with some manual inspection and testing.";

      final offset = node.firstTokenAfterCommentAndMetadata.offset;
      yieldPatch(lineComment(commentContents), offset, offset);
    }
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

    // No data; either not a prop, our data is outdated, or it's never actually set.
    if (recommendation == null) {
      final isPropsClass = node.declaredElement?.enclosingElement
              ?.tryCast<InterfaceElement>()
              ?.allSupertypes
              .any((s) => s.element.name == 'UiProps') ??
          false;
      if (isPropsClass) {
        final commentContents =
            "TODO(orcm.required_props): No data for prop; either it's never set,"
            " all places it was set were on dynamic usages,"
            " or requiredness data was collected on a version before this prop was added.";
        final offset =
            fieldDeclaration.firstTokenAfterCommentAndMetadata.offset;
        // Add back the indent we "stole" from the field by inserting our comment at its start.
        yieldPatch(
            lineComment(commentContents) + '  ', offset, offset);
        // Mark as optional
        if (type != null) {
          yieldPatch(nullableHint, type.end, type.end);
        }
      }
      return;
    }

    if (recommendation.isRequired) {
      // Don't unnecessarily annotate it as non-nullable;
      // let the migrator tool do that.
      final offset = fieldDeclaration.firstTokenAfterCommentAndMetadata.offset;
      yieldPatch('$lateHint ', offset, offset);
    } else {
      if (type != null) {
        yieldPatch(nullableHint, type.end, type.end);
      }
    }
  }
}

class PropRequirednessRecommender {
  final PropRequirednessResults _propRequirednessResults;

  final num privateRequirednessThreshold;
  final num privateMaxAllowedSkipRate;
  final num publicRequirednessThreshold;
  final num publicMaxAllowedSkipRate;

  PropRequirednessRecommender(
    this._propRequirednessResults, {
    required this.privateRequirednessThreshold,
    required this.privateMaxAllowedSkipRate,
    required this.publicRequirednessThreshold,
    required this.publicMaxAllowedSkipRate,
  }) {
    ({
      'privateRequirednessThreshold': privateRequirednessThreshold,
      'privateMaxAllowedSkipRate': privateMaxAllowedSkipRate,
      'publicRequirednessThreshold': publicRequirednessThreshold,
      'publicMaxAllowedSkipRate': publicMaxAllowedSkipRate,
    }).forEach((name, value) {
      _validateWithinRange(value, name: name, min: 0, max: 1);
    });
  }

  PropRecommendation? getRecommendation(FieldElement propField) {
    final propName = propField.name;

    final mixinResults = _getMixinResult(propField.enclosingElement);
    if (mixinResults == null) return null;

    final propResults = mixinResults.propResultsByName[propName];
    if (propResults == null) return null;

    final skipRateReason = _getMixinSkipRateReason(mixinResults);
    if (skipRateReason != null) {
      return PropRecommendation.optional(skipRateReason);
    }

    final totalRequirednessRate = propResults.totalRate;

    final isPublic = mixinResults.visibility.isPublicForUsages;
    final requirednessThreshold =
        isPublic ? publicRequirednessThreshold : privateRequirednessThreshold;

    if (totalRequirednessRate < requirednessThreshold) {
      final reason = RequirednessThresholdOptionalReason();
      return PropRecommendation.optional(reason);
    } else {
      return const PropRecommendation.required();
    }
  }

  MixinResult? _getMixinResult(Element propsElement) {
    final packageName = getPackageName(propsElement.source!.uri);
    final propsId = uniqueElementId(propsElement);
    return _propRequirednessResults.mixinResultsByIdByPackage[packageName]
        ?[propsId];
  }

  SkipRateOptionalReason? _getMixinSkipRateReason(MixinResult mixinResults) {
    final skipRate = mixinResults.usageSkipRate;

    final isPublic = mixinResults.visibility.isPublicForUsages;
    final maxAllowedSkipRate =
        isPublic ? publicMaxAllowedSkipRate : privateMaxAllowedSkipRate;

    return skipRate > maxAllowedSkipRate
        ? SkipRateOptionalReason(
            skipRate: skipRate,
            maxAllowedSkipRate: maxAllowedSkipRate,
            isPublic: isPublic)
        : null;
  }

  SkipRateOptionalReason? getMixinSkipRateReasonForElement(
      Element propsElement) {
    final mixinResults = _getMixinResult(propsElement);
    if (mixinResults == null) return null;

    return _getMixinSkipRateReason(mixinResults);
  }
}

void _validateWithinRange(num value,
    {required num min, required num max, required String name}) {
  if (value < min || value > max) {
    throw ArgumentError.value(
        value, name, 'must be between $min and $max (inclusive)');
  }
}

extension on Visibility {
  bool get isPublicForUsages {
    switch(this) {
      case Visibility.public:
      case Visibility.indirectlyPublic:
      case Visibility.unknown:
        return true;
      case Visibility.private:
        return false;
    }
  }

  // ignore: unused_element
  bool get isPublicForMixingIn {
    switch(this) {
      case Visibility.public:
      case Visibility.unknown:
        return true;
      case Visibility.indirectlyPublic:
      case Visibility.private:
        return false;
    }
  }
}

class PropRecommendation {
  final bool isRequired;
  final OptionalReason? reason;

  const PropRecommendation.required()
      : isRequired = true,
        reason = null;

  const PropRecommendation.optional(this.reason) : isRequired = false;
}

abstract class OptionalReason {}

class SkipRateOptionalReason extends OptionalReason {
  final num skipRate;
  final num maxAllowedSkipRate;
  final bool isPublic;

  SkipRateOptionalReason({
    required this.skipRate,
    required this.maxAllowedSkipRate,
    required this.isPublic,
  });
}

class RequirednessThresholdOptionalReason extends OptionalReason {
  RequirednessThresholdOptionalReason();
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
