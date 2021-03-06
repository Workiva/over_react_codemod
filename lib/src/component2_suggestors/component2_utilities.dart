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
import 'component2_constants.dart';

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
      classNode.metadata.any(
          (m) => overReact16Component2AnnotationNames.contains(m.name.name))) {
    return true;
  } else {
    return false;
  }
}

const _safeMixinNames = {
  'FocusRestorer',
  'FormControlApi',
  'FormControlApiV2',
  'TypedSnapshot',
};

/// Returns whether or not [classNode] has one or more mixins.
bool hasOneOrMoreMixinWithPotentialLifecycleOverrides(
        ClassDeclaration classNode) =>
    classNode?.withClause != null &&
    classNode.withClause.mixinTypes
        .any((t) => !_safeMixinNames.contains(t.name.name));

/// Returns whether or not [classNode] can be fully upgraded to Component2.
///
/// In order for a component to be fully upgradable, the component must:
///
/// * not have a `with` clause
/// * extend directly from `UiComponent`, `UiStatefulComponent`,
/// `FluxUiComponent`, `FluxUiStatefulComponent`, or `react.Component`
/// * contain only the lifecycle methods that the codemod updates:
///   * `componentWillMount` (updated to `init`)
///   * `render`
///   * `componentDidUpdate`
bool fullyUpgradableToComponent2(ClassDeclaration classNode) {
  var extendsName = classNode?.extendsClause?.superclass?.name;
  if (extendsName == null) {
    return false;
  }

  if (hasOneOrMoreMixinWithPotentialLifecycleOverrides(classNode)) {
    return false;
  }

  // Check that class extends directly from Component classes.
  String reactImportName =
      getImportNamespace(classNode, 'package:react/react.dart');

  final componentClassNames = {...overReactBaseComponentClasses};

  if (reactImportName != null) {
    componentClassNames.add('$reactImportName.Component');
    componentClassNames.add('$reactImportName.Component2');
  }

  if (!componentClassNames.contains(extendsName.name)) {
    return false;
  }

  // Check that all deprecated lifecycle methods contained in the class will be
  // updated by a codemod.
  for (var member in classNode.members) {
    if (member is MethodDeclaration &&
        deprecatedLifecycleMethods.contains(member.name.name) &&
        !lifecycleMethodsWithCodemods.contains(member.name.name)) {
      return false;
    }
  }

  return true;
}

/// Returns whether or not [classNode] can be extended from.
///
/// A component class can be extended from if one of the following is true:
///
/// * `abstract` keyword on component class
/// * Generic parameters on component class
/// * `@AbstractProps` in the same file
bool canBeExtendedFrom(ClassDeclaration classNode) {
  if (classNode != null &&
      (classNode.abstractKeyword != null ||
          classNode.typeParameters != null ||
          classNode.root.toSource().contains('@AbstractProps'))) {
    return true;
  }
  return false;
}
