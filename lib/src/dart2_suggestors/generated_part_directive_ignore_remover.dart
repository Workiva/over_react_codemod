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

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../constants.dart';

/// Suggestor that removes the `// ignore: ...` comment attached to each
/// over_react generated part directive.
class GeneratedPartDirectiveIgnoreRemover extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final _ignoreComment = RegExp(r'[\n]?[ ]*//[ ]*ignore:.*');

  @override
  visitPartDirective(PartDirective node) {
    if (!node.uri.stringValue.endsWith(overReactGeneratedExtension)) {
      return;
    }

    final prevLineEnd = node.offset - 1;
    final prevLineStart = sourceFile.getOffset(sourceFile.getLine(prevLineEnd));
    final prevLine = sourceFile.getText(prevLineStart, prevLineEnd);
    if (_ignoreComment.hasMatch(prevLine)) {
      yieldPatch(prevLineStart, prevLineEnd + 1, '');
    }
  }
}
