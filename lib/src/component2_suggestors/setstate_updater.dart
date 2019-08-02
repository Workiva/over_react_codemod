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

/// Suggestor that renames all props and state classes to have the required `_$`
/// prefix.
///
/// If [includeMixins] is true, props and state mixins will also be renamed.
class SetStateUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  SetStateUpdater();

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.methodName.name == 'setState' && node.argumentList.arguments
        .first is MethodInvocation) {

      int length = node.toString().indexOf('(');

      yieldPatch(node.offset, node.offset + length, 'setStateWithUpdater');
    }
  }
}
