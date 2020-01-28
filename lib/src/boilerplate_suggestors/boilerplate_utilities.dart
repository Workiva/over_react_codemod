// Copyright 2020 Workiva Inc.
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
import 'package:over_react_codemod/src/component2_suggestors/component2_utilities.dart';

/// Returns whether or not [node] is declared in the same file as a Component2 component.
bool isAssociatedWithComponent2(ClassDeclaration node) {
  bool containsComponent2 = false;
  CompilationUnit unit = node.root;

  unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
    if(extendsComponent2(classNode)) {
      containsComponent2 = true;
    }
  });

  return containsComponent2;
}
