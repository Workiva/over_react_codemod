// Copyright 2021 Workiva Inc.
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
import 'package:over_react_codemod/src/util.dart';

import 'dart2_9_utilities.dart';

/// Suggestor that updates factory declarations and configs to the new Dart 2.9
/// boilerplate syntax.
///
/// Specifically:
/// * Removes left hand typing.
/// * Updates generated factory configs to be private.
/// * Type casts generated factories and configs.
///
/// Factory Declarations:
///
/// ```dart
/// // Before
/// UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
///
/// // After
/// final Foo = _$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
/// ```
///
/// Connected Components:
///
/// ```
/// // Before
/// UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
///   mapStateToProps: (state) => (Foo()
///     ..foo = state.foo
///     ..bar = state.bar
///   ),
/// )(
///   _$Foo, // ignore: undefined_identifier
/// );
///
/// // After
/// UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
///   mapStateToProps: (state) => (Foo()
///     ..foo = state.foo
///     ..bar = state.bar
///   ),
/// )(
///   _$Foo as UiFactory<FooProps>, // ignore: undefined_identifier
/// );
/// ```
///
/// Function Components:
/// ```
/// // Before
/// UiFactory<FooProps> Foo = uiFunction(
///   (props) {},
///   $FooConfig, // ignore: undefined_identifier
/// );
///
/// // After
/// final Foo = uiFunction<FooProps>(
///   (props) {},
///   _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
/// );
/// ```
class GeneratedFactoryMigrator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    final generatedArg = getGeneratedArg(node);
    if (generatedArg == null) return;

    // Update the generated argument to be private in preparation for Dart 2.12
    // when all names beginning with the `_$` prefix are assumed to be
    // generated.
    if (!generatedArg.name.startsWith('_')) {
      yieldPatch(generatedArg.offset, generatedArg.offset, '_');
    }

    // Do not update if the generated argument is already type casted.
    if (generatedArg.parent is AsExpression) return;

    // Find the name of the props class associated with the argument list in
    // order to accurately type cast the generated argument.
    String propsName;

    final variableList =
        generatedArg.thisOrAncestorOfType<VariableDeclarationList>();
    final type = variableList?.type;
    if (type is TypeName && type.name.name == 'UiFactory') {
      // If available, use the left hand typing of the parent variable declaration
      // to determine the props class name.
      propsName = (type.typeArguments.arguments.first as TypeName).name.name;

      if (generatedArg.name.endsWith('Config')) {
        // Remove left hand typing only from factory config usages because
        // connected components still need left hand typing.
        // See issue: <https://github.com/dart-lang/sdk/issues/44236>.
        yieldPatch(type.offset, type.end, 'final');
      }
    }

    final method = generatedArg.thisOrAncestorOfType<MethodInvocation>();
    if (propsName != null && method != null && method.typeArguments == null) {
      // If the left hand typing was removed above, add generic type arguments
      // to the method invocation.
      yieldPatch(method.methodName.end, method.methodName.end, '<$propsName>');
    }

    // If available, use the generic type argument on the parent method
    // invocation to determine the props class name.
    propsName ??= method?.typeArguments?.arguments
        ?.firstWhere(
            (type) => type is TypeName && type.name.name.endsWith('Props'))
        ?.toSource();

    if (propsName != null) {
      // Add type casting to the generated argument.
      yieldPatch(
        generatedArg.end,
        generatedArg.end,
        ' as ${generatedArg.name.endsWith('Config') ? 'UiFactoryConfig' : 'UiFactory'}<$propsName>',
      );
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Remove left hand typing and type cast the generated initializer only if
    // the factory declaration is in the new boilerplate syntax.
    if (isClassComponentFactory(node) && !isLegacyFactoryDecl(node)) {
      final initializer = node.variables?.variables?.first?.initializer;
      final type = node.variables?.type;
      if (initializer is SimpleIdentifier && type is NamedType) {
        yieldPatch(type.offset, type.end, 'final');
        yieldPatch(initializer.end, initializer.end, ' as $type');
      }
    }
  }
}
