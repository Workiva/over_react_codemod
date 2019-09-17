// Copyright 2019 Workiva Inc.
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
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

import '../constants.dart';
import 'component2_utilities.dart';

/// Suggestor that replaces `UiComponent` with `UiComponent2` in extends clauses
/// and updates the annotation to `@Component2()`.
///
/// The same update is made for `UiStatefulComponent`, `FluxUiComponent`,
/// `FluxUiStatefulComponent` and `react.Component` (including instances where
/// `react.Component` is used for typing).
/// `react.dart` imports are also updated to show Component2 as well
/// as Component.
class ClassNameAndAnnotationMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool allowPartialUpgrades;
  final bool shouldUpgradeAbstractComponents;

  ClassNameAndAnnotationMigrator({
    this.allowPartialUpgrades = true,
    this.shouldUpgradeAbstractComponents = false,
  });

  Iterable<String> get migrateAnnotations =>
      overReact16ComponentAnnotationNamesToMigrate;

  @override
  visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    if (node.uri?.stringValue != 'package:react/react.dart' ||
        node.combinators.isEmpty) {
      return;
    }

    CompilationUnit unit = node.thisOrAncestorMatching((ancestor) {
      return ancestor is CompilationUnit;
    });

    // Check if the import needs to show Component2.
    bool shouldUpdateImport = true;
    if (!allowPartialUpgrades) {
      shouldUpdateImport = false;
      unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
        if (fullyUpgradableToComponent2(classNode)) {
          shouldUpdateImport = true;
        }
      });
    }

    // Add Component2 to import show list.
    var showNamesList = (node.combinators.firstWhere(
            (combinator) => combinator is ShowCombinator,
            orElse: () => null) as ShowCombinator)
        ?.shownNames;
    if (shouldUpdateImport &&
        showNamesList != null &&
        !showNamesList.any((name) => name.toSource() == 'Component2')) {
      yieldPatch(
        showNamesList.last.end,
        showNamesList.last.end,
        ', Component2',
      );
    }
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if ((!allowPartialUpgrades && !fullyUpgradableToComponent2(node)) ||
        (!shouldUpgradeAbstractComponents && canBeExtendedFrom(node))) {
      return;
    }

    var extendsName = node.extendsClause?.superclass?.name;
    if (extendsName == null) {
      return;
    }

    String reactImportName =
        getImportNamespace(node, 'package:react/react.dart');
    bool wasUpdated = false;

    if (reactImportName != null &&
        extendsName.name == '$reactImportName.Component') {
      // Update `react.Component` extends clause.
      yieldPatch(
        extendsName.end,
        extendsName.end,
        '2',
      );

      wasUpdated = true;
    } else {
      if (!node.metadata.any((m) =>
          migrateAnnotations.contains(m.name.name) ||
          overReact16Component2AnnotationNames.contains(m.name.name))) {
        // Only looking for classes annotated with `@Props()`, `@State()`,
        // `@AbstractProps()`, or `@AbstractState()`. If [renameMixins] is true,
        // also includes `@PropsMixin()` and `@StateMixin()`.
        return;
      }

      // Update annotation.
      Iterable<Annotation> annotationRefs =
          node.metadata.where((m) => migrateAnnotations.contains(m.name.name));

      annotationRefs.forEach((annotationRef) {
        if (annotationRef.name.name.contains('2')) {
          return;
        }

        yieldPatch(
          annotationRef.name.end,
          annotationRef.name.end,
          '2',
        );

        wasUpdated = true;
      });

      if (upgradableV1ComponentClassNames.contains(extendsName.name)) {
        // Update `UiComponent` or `UiStatefulComponent` extends clause.
        yieldPatch(
          extendsName.end,
          extendsName.end,
          '2',
        );

        wasUpdated = true;
      }
    }

    if (wasUpdated) {
      _addFixMeCommentPatches(node, extendsName);
    }
  }

  void _addFixMeCommentPatches(ClassDeclaration node, Identifier extendsName) {
    final extendsNameStr = extendsName.toString().replaceAll('2', '');
    final classToUpgradeTo =
        upgradableV1ComponentClassNames.contains(extendsNameStr)
            ? '`${extendsNameStr}2`'
            : 'a class that now extends from `UiComponent2`';

    [
      _FixMeCommentPatch(hasOneOrMoreMixins, () => node,
          'FIXME: Before upgrading this component to $classToUpgradeTo, verify that none of the mixin(s) contain implementations of any React lifecycle methods that are not supported in $classToUpgradeTo.'),
      _FixMeCommentPatch(
          (node) => shouldUpgradeAbstractComponents && canBeExtendedFrom(node),
          () => node,
          'FIXME: Abstract class has been updated to $classToUpgradeTo. This is a breaking change if this class is exported.'),
    ].forEach((patch) {
      if (!patch.shouldYieldPatch(node) ||
          hasMultilineDocComment(node, sourceFile, patch.commentSrc)) {
        return;
      }

      final patchOffset = node.metadata?.beginToken?.offset ??
          node.firstTokenAfterCommentAndMetadata.offset;
      yieldPatch(patchOffset, patchOffset, patch.commentSrc);
    });
  }
}

class _FixMeCommentPatch {
  final bool Function(ClassDeclaration node) shouldYieldPatch;
  final ClassDeclaration Function() getNode;

  _FixMeCommentPatch(this.shouldYieldPatch, this.getNode, String commentSrc) {
    final node = getNode();
    final indentationLevel = node.beginToken.charOffset;
    final fixmeCommentLineStart =
        indentationLevel == 0 ? '///' : (' ' * indentationLevel) + '///';
    final fixmeCommentStart = node.documentationComment != null
        ? '$fixmeCommentLineStart\n$fixmeCommentLineStart'
        : fixmeCommentLineStart;
    final fixmeCommentEnd = '\n';

    _commentSrc = '$fixmeCommentStart $commentSrc$fixmeCommentEnd';
  }

  String _commentSrc;
  String get commentSrc => _commentSrc;
}
