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
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

import 'recommender.dart';

const _todoWithPrefix = 'TODO(orcm.required_props)';

class RequiredPropsMigrator extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  final PropRequirednessRecommender _propRequirednessRecommender;
  final bool _trustRequiredAnnotations;

  RequiredPropsMigrator(
    this._propRequirednessRecommender, {
    required bool trustRequiredAnnotations,
  }) : _trustRequiredAnnotations = trustRequiredAnnotations;

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
          "$_todoWithPrefix: This codemod couldn't reliably determine requiredness for these props"
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

    void yieldLateHintPatch() {
      // Don't unnecessarily annotate it as non-nullable;
      // let the migrator tool do that.
      final offset = fieldDeclaration.firstTokenAfterCommentAndMetadata.offset;
      yieldPatch('$lateHint ', offset, offset);
    }

    void yieldOptionalHintPatch() {
      if (type != null) {
        yieldPatch(nullableHint, type.end, type.end);
      }
    }

    final requiredPropAnnotation = fieldDeclaration.metadata.firstWhereOrNull(
        (m) => const {'requiredProp', 'nullableRequiredProp'}
            .contains(m.name.name));

    if (requiredPropAnnotation != null) {
      // Always remove the annotation, since it can't be combined with late required props.
      yieldPatch(
          '',
          requiredPropAnnotation.offset,
          // Patch the whitespace up until the next token/comment, so that we take
          // any newline along with this annotation.
          requiredPropAnnotation.endToken.nextTokenOrCommentOffset ??
              requiredPropAnnotation.end);

      if (_trustRequiredAnnotations) {
        yieldLateHintPatch();
        return;
      }
    }

    final recommendation =
        _propRequirednessRecommender.getRecommendation(element);

    // No data; either not a prop, it's never actually set on any non-skipped usages, or our data is outdated.
    if (recommendation == null) {
      final skipReasonForEnclosingClass = _propRequirednessRecommender
          .getMixinSkipRateReasonForElement(element.enclosingElement);

      final isPropsClass = skipReasonForEnclosingClass != null ||
          (node.declaredElement?.enclosingElement
                  ?.tryCast<InterfaceElement>()
                  ?.allSupertypes
                  .any((s) => s.element.name == 'UiProps') ??
              false);
      if (isPropsClass) {
        // Only comment about missing data if we're not already making this optional
        // because the class was skipped.
        if (skipReasonForEnclosingClass == null) {
          final commentContents =
              "$_todoWithPrefix: No data for prop; either it's never set,"
              " all places it was set were on dynamic usages,"
              " or requiredness data was collected on a version before this prop was added.";
          final offset =
              fieldDeclaration.firstTokenAfterCommentAndMetadata.offset;
          // Add back the indent we "stole" from the field by inserting our comment at its start.
          yieldPatch(lineComment(commentContents) + '  ', offset, offset);
        }
        // Mark as optional
        yieldOptionalHintPatch();
      }
      return;
    }

    if (recommendation.isRequired) {
      yieldLateHintPatch();
    } else {
      yieldOptionalHintPatch();
    }
  }
}

extension on Token {
  /// The offset of the next token or comment
  /// (since comments can occur before the next token)
  /// following this token, or null if nothing follows it.
  int? get nextTokenOrCommentOffset {
    final next = this.next;
    if (next == null) return null;
    final nextTokenOrComment = next.precedingComments ?? next;
    return nextTokenOrComment.offset;
  }
}
