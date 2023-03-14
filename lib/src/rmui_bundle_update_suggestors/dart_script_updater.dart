// Copyright 2023 Workiva Inc.
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
import 'package:over_react_codemod/src/rmui_preparation_suggestors/constants.dart';
import 'package:over_react_codemod/src/util.dart';

import 'constants.dart';

/// Suggestor that updates the [existingScriptPath] <script> line to [newScriptPath] and
/// adds `type="module"` attribute to the script tag in a Dart string literal or list of string literals.
///
/// Meant to be run on Dart files (use [HtmlScriptAdder] to run on HTML files).
class DartScriptUpdater extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  final String existingScriptPath;
  final String newScriptPath;

  DartScriptUpdater(this.existingScriptPath, this.newScriptPath);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // This value includes the quotation marks.
    final stringValue = node.literal.lexeme;

    final relevantScriptTags = [
      ...Script(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(stringValue),
      ...Script(pathSubpattern: newScriptPath).pattern.allMatches(stringValue)
    ];

    // Do not update if neither the existingScriptPath nor newScriptPath are in the file.
    if (relevantScriptTags.isEmpty) return;

    // Add type="module" attribute to script tag.
    for (final scriptTagMatch in relevantScriptTags) {
      final scriptTag = scriptTagMatch.group(0);
      if (scriptTag == null) continue;
      final typeAttributes = typeAttributePattern.allMatches(scriptTag);
      if (typeAttributes.isNotEmpty) {
        final attribute = typeAttributes.first;
        final value = attribute.group(1);
        if (value == 'module') {
          continue;
        } else {
          // If the value of the type attribute is not "module", overwrite it.
          yieldPatch(
            typeModuleAttribute,
            node.offset + scriptTagMatch.start + attribute.start,
            node.offset + scriptTagMatch.start + attribute.end,
          );
        }
      } else {
        // If the type attribute does not exist, add it.
        final srcAttribute = srcAttributePattern.allMatches(scriptTag);
        yieldPatch(
          ' ${typeModuleAttribute}',
          node.offset + scriptTagMatch.start + srcAttribute.first.end,
          node.offset + scriptTagMatch.start + srcAttribute.first.end,
        );
      }
    }

    // Update existing path to new path.
    final scriptMatches = existingScriptPath.allMatches(stringValue);
    scriptMatches.forEach((match) async {
      yieldPatch(
        newScriptPath,
        node.offset + match.start,
        node.offset + match.end,
      );
    });

    // yield* Stream.fromIterable(patches);

    // Do not add the script if it already exists in the string.
    // if (scriptToAdd.pattern.hasMatch(stringValue)) return;

    // if (parent is VariableDeclaration) {
    //   final scriptMatches = reactJsScript.pattern.allMatches(stringValue);
    //
    //   if (scriptMatches.isNotEmpty) {
    //     final lastMatch = scriptMatches.last;
    //
    //     // Only add [scriptToAdd] if it has the same prod/dev status as the
    //     // react-dart js [lastMatch] found.
    //     final lastMatchValue = lastMatch.group(0)!;
    //     // if (isProd != isScriptProd(lastMatchValue)) return;
    //
    //     yieldPatch(
    //       // Add the new script with the same indentation as the line before it.
    //       '\n${lastMatch.precedingWhitespaceGroup}'
    //       '${scriptToAdd.scriptTag(pathPrefix: lastMatch.pathPrefixGroup)}',
    //       // Add [scriptToAdd] right after the location of [lastMatch] within
    //       // the string literal [node].
    //       node.offset + lastMatch.end,
    //       node.offset + lastMatch.end,
    //     );
    //   }
    // } else if (parent is ListLiteral) {
    //   // Do not add the script to the list if it is already there.
    //   if (parent.elements.any((element) =>
    //       element is SimpleStringLiteral &&
    //       scriptToAdd.pattern.hasMatch(element.literal.lexeme))) {
    //     return;
    //   }
    //
    //   // Verify [node.value] (without the quotes) is an exact match.
    //   final scriptMatch = reactJsScript.pattern.firstMatch(node.value);
    //   final isExactMatch =
    //       scriptMatch != null && scriptMatch.group(0)! == scriptMatch.input;
    //   if (scriptMatch != null && isExactMatch) {
    //     // To avoid adding the [scriptToAdd] twice, verify that [node] is the
    //     // last matching react script in the list.
    //     final lastMatchElement = parent.elements.lastWhere((element) =>
    //         element is SimpleStringLiteral &&
    //         reactJsScript.pattern.firstMatch(element.value) != null);
    //     if (node.offset != lastMatchElement.offset) return;
    //
    //     // Only add [scriptToAdd] if it has the same prod/dev status as the
    //     // react-dart js [scriptMatch] found.
    //     final scriptMatchValue = scriptMatch.group(0)!;
    //     if (isProd != isScriptProd(scriptMatchValue)) return;
    //
    //     yieldPatch(
    //       // Add the new script to the list.
    //       ',\n\'${scriptToAdd.scriptTag(pathPrefix: scriptMatch.pathPrefixGroup)}\'',
    //       node.end,
    //       node.end,
    //     );
    //   }
    // }
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);
}
