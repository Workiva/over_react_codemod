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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';

import 'boilerplate_utilities.dart';

/// Suggestor that replaces abstract props class types with the newly created mixin types in the generic parameter list.
class AbstractComponentClassGenericTypeMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final ClassToMixinConverter converter;

  AbstractComponentClassGenericTypeMigrator(this.converter);

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!node.isAbstract || node.typeParameters == null) return;
    final typeParameters = node.typeParameters.typeParameters;
    if (typeParameters == null) return;
    if (!typeParameters.any((parameter) {
      final type = _getTypeNameFromTypeParameter(parameter);
      if (type == null) return false;

      final classWasConverted =
          converter.convertedClassNames.containsKey(type.name.name);
      final mixinNameDiffersFromOriginalClassName =
          type.name.name != converter.convertedClassNames[type.name.name];
      return classWasConverted && mixinNameDiffersFromOriginalClassName;
    })) {
      return;
    }

    for (var typeParameter in typeParameters) {
      final type = _getTypeNameFromTypeParameter(typeParameter);
      if (type == null) return;
      final convertedName = converter.convertedClassNames[type.name.name];

      if (converter.convertedClassNames.containsKey(type.name.name) &&
          type.name.name != convertedName) {
        yieldPatch(type.offset, type.end, convertedName);
      }
    }
  }

  TypeName _getTypeNameFromTypeParameter(TypeParameter parameter) {
    final typeNames = parameter.childEntities.whereType<TypeName>();
    if (typeNames.isEmpty) return null;
    return typeNames.first;
  }
}
