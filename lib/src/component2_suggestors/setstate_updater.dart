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
import '../util.dart';

/// Suggestor that updates a [setState] call to [setStateWithUpdater] in the
/// case that the first argument is a function.
class SetStateUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  SetStateUpdater();

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.argumentList.arguments.isEmpty) return;

    final firstArg = node.argumentList.arguments.first;

    if (node.methodName.name == 'setState' && firstArg is MethodInvocation) {
      if (firstArg.methodName.name == 'newState') return;

      int length = node.toString().indexOf('(');

      yieldPatch(node.offset, node.offset + length, 'setStateWithUpdater');
    }
  }
}
