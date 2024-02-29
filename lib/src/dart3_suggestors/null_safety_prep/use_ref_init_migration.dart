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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

/// Suggestor that finds instances of `useRef` function invocations that
/// pass an argument, and replaces them with `useRefInit` to prep for
/// null safety.
///
/// Example:
///
/// ```dart
/// // Before
/// final ref = useRef(someNonNulLValue);
/// // After
/// final ref = useRefInit(someNonNulLValue);
/// ```
class UseRefInitMigration extends RecursiveAstVisitor with ClassSuggestor {
  ResolvedUnitResult? _result;

  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    if (node.arguments.isEmpty) return;

    dynamic possibleInvocation = node.parent;
    if (possibleInvocation is MethodInvocation) {
      String fnName = '';
      if (possibleInvocation.function is SimpleIdentifier) {
        fnName = (possibleInvocation.function as SimpleIdentifier).name;
      }

      if (fnName == 'useRef') {
        yieldPatch('useRefInit', possibleInvocation.function.offset,
            possibleInvocation.function.end);
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _result = await context.getResolvedUnit();
    if (_result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result!.unit.accept(this);
  }
}
