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

import '../constants.dart';

/// Returns the import namespace of the import referencing [uri].
String getImportNamespace(AstNode node, String uri) {
  CompilationUnit importList = node.thisOrAncestorMatching((ancestor) {
    return ancestor is CompilationUnit;
  });

  ImportDirective reactImport = importList.directives.lastWhere(
      (dir) => dir is ImportDirective && dir.uri?.stringValue == uri,
      orElse: () => null);

  return reactImport?.prefix?.name;
}

/// Returns whether or not [classNode] extends Component2 (either by having the
/// `@Component2` annotation or by extending `react.Component2`).
bool extendsComponent2(ClassDeclaration classNode) {
  var extendsName = classNode?.extendsClause?.superclass?.name;
  if (extendsName == null) {
    return false;
  }

  String reactImportName =
      getImportNamespace(classNode, 'package:react/react.dart');

  if ((reactImportName != null &&
          extendsName.name == '$reactImportName.Component2') ||
      classNode.metadata
          .any((m) => overReact16AnnotationNames.contains(m.name.name))) {
    return true;
  } else {
    return false;
  }
}

/// Returns whether or not [classNode] can be fully upgraded to Component2.
///
/// In order for a component to be fully upgradable, the component must:
///
/// * extend directly from `UiComponent`/`UiStatefulComponent`/`react.Component`
/// * contain only the lifecycle methods that the codemod updates:
///   * `componentWillMount` (updated to `init`)
///   * `render`
///   * `componentDidUpdate`
bool canBeFullyUpgradedToComponent2(ClassDeclaration classNode) {
  var extendsName = classNode?.extendsClause?.superclass?.name;
  if (extendsName == null) {
    return false;
  }

  // Check that class extends directly from Component classes.
  String reactImportName =
      getImportNamespace(classNode, 'package:react/react.dart');

  var componentClassNames = [
    'UiComponent',
    'UiComponent2',
    'UiStatefulComponent',
    'UiStatefulComponent2',
  ];

  if (reactImportName != null) {
    componentClassNames.add('$reactImportName.Component');
    componentClassNames.add('$reactImportName.Component2');
  }

  if (!componentClassNames.contains(extendsName.name)) {
    return false;
  }

  // Check that all lifecycle methods contained in the class will be
  // updated by a codemod.
  var lifecycleMethodsWithCodemods = [
    'componentWillMount',
    'init',
    'render',
    'componentDidUpdate',
  ];

  for (var member in classNode.members) {
    if (member is MethodDeclaration &&
        !lifecycleMethodsWithCodemods.contains(member.name.name)) {
      return false;
    }
  }

  return true;
}
