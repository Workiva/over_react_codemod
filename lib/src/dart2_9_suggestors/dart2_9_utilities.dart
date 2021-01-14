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
import 'package:analyzer/dart/ast/token.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';

/// Returns the generated argument from [argList].
///
/// Used specifically to find the generated factory argument in `connect`
/// usages.
///
/// Returns `null` if no generated argument found.
///
/// Example:
///
/// | input                          | output |
/// |--------------------------------|--------|
/// | (_$Foo)                        | _$Foo  |
/// | (castUiFactory(_$Foo))         | _$Foo  |
/// | (Foo)                          | null   |
SimpleIdentifier getGeneratedFactoryArg(ArgumentList argList) {
  final args = argList.arguments;
  if (args.length != 1) return null;

  final generatedPrefix = '_\$';

  final method =
      argList.thisOrAncestorOfType<FunctionExpressionInvocation>()?.function;
  if (method is MethodInvocation && method.methodName.name == 'connect') {
    final generatedArg = args.first;
    if (generatedArg is SimpleIdentifier) {
      return generatedArg.name.startsWith(generatedPrefix)
          ? generatedArg
          : null;
    } else if (generatedArg is MethodInvocation &&
        generatedArg.methodName.name == castFunctionName) {
      final arg = generatedArg.argumentList.arguments.first;
      return arg is SimpleIdentifier && arg.name.startsWith(generatedPrefix)
          ? arg
          : null;
    }
  }

  return null;
}

/// Returns the generated factory config argument from [argList].
///
/// Used specifically to find the generated factory config in `uiFunction` /
/// `uiForwardRef` usages.
///
/// Returns `null` if no generated argument found.
///
/// Example:
///
/// | input                                                  | output      |
/// |--------------------------------------------------------|-------------|
/// | ((props) {}, $FooConfig)                               | $FooConfig  |
/// | ((props) {}, _$FooConfig)                              | _$FooConfig |
/// | ((props) {}, UiFactoryConfig())                        | null        |
SimpleIdentifier getGeneratedFactoryConfigArg(ArgumentList argList) {
  final args = argList.arguments;
  if (args.length != 2) return null;

  final configPattern = RegExp(r'_?\$\S*Config$');

  final generatedArg = args[1];
  return generatedArg is SimpleIdentifier &&
          generatedArg.name.startsWith(configPattern)
      ? generatedArg
      : null;
}

/// Returns whether or not [node] is a class component factory declaration.
bool isClassComponentFactory(TopLevelVariableDeclaration node) {
  final type = node.variables?.type;
  if (type != null && type is NamedType && type?.name?.name == 'UiFactory') {
    final initializer = node.variables?.variables?.first?.initializer;
    if (initializer is SimpleIdentifier) {
      return initializer.name.startsWith('_\$');
    } else if (initializer is MethodInvocation &&
        initializer.methodName.name == castFunctionName) {
      return initializer.argumentList.arguments.first
          .toSource()
          .startsWith('_\$');
    }
  }

  return false;
}

/// Returns whether or not [node] is in the legacy boilerplate syntax.
bool isLegacyFactoryDecl(TopLevelVariableDeclaration node) {
  final annotation = node.metadata?.firstWhere(
      (m) => m.toSource().startsWith('@Factory'),
      orElse: () => null);
  return isClassComponentFactory(node) && annotation != null;
}

/// Iterates through the [comment] token stream and removes all ignore
/// comments containing [ignoreToRemove] using the [yieldPatch] provided.
///
/// The entire ignore comment will only be removed if [ignoreToRemove] is the only
/// item in the list to ignore. Otherwise, [ignoreToRemove] will just be
/// removed from the list.
///
/// Example:
///
/// Calling:
/// ```
/// removeIgnoreComment(
///   node.beginToken.precedingComments,
///   'undefined_identifier',
///   yieldPatch,
/// );
/// ```
/// Will yield the following changes depending on the value of [comment]:
///
/// `// ignore: undefined_identifier` => entire comment will be removed
///
/// `// ignore: invalid_assignment, undefined_identifier` => `// ignore: invalid_assignment`
///
/// `// ignore: invalid_assignment` => `// ignore: invalid_assignment`
void removeIgnoreComment(
    Token comment, String ignoreToRemove, YieldPatch yieldPatch) {
  if (comment == null) return;

  final lexeme = comment.lexeme.replaceAll(' ', '').toLowerCase();
  if (lexeme.startsWith('//ignore:')) {
    final ignoreList =
        lexeme.replaceFirst(RegExp('\/\/ignore\:'), '').split(',');
    if (ignoreToRemove == null ||
        (ignoreList.contains(ignoreToRemove) && ignoreList.length == 1)) {
      yieldPatch(comment.previous?.end ?? comment.offset, comment.end, '');
    } else if (ignoreList.contains(ignoreToRemove)) {
      ignoreList.removeWhere((i) => i == ignoreToRemove);
      final newIgnoreComment = '// ignore: ${ignoreList.join(', ')}';
      yieldPatch(comment.offset, comment.end, newIgnoreComment);
    }
  }

  removeIgnoreComment(comment.next, ignoreToRemove, yieldPatch);
}

extension ListHelper<T> on List {
  void addIfNotNull(T object) {
    if (object != null) {
      this.add(object);
    }
  }
}
