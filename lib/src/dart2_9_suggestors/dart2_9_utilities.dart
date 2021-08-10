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
import 'package:collection/collection.dart' show IterableExtension;
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';

import '../util.dart';

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
SimpleIdentifier? getGeneratedFactoryConfigArg(ArgumentList argList) {
  final args = argList.arguments;
  if (args.length != 2) return null;

  final configPattern = RegExp(r'_?\$\S*Config$');

  final generatedArg = args[1];
  return generatedArg is SimpleIdentifier &&
          generatedArg.name.startsWith(configPattern)
      ? generatedArg
      : null;
}

/// Returns the generated factory in the initializer of [node].
///
/// Returns null if a generated factory is not found.
///
/// Example:
///
/// | input                                                                | output |
/// |----------------------------------------------------------------------|--------|
/// | UiFactory<FooProps> Foo = _$Foo;                                     | _$Foo  |
/// | UiFactory<FooProps> Foo = connect<SomeState, FooProps>(...)(_$Foo);  | _$Foo  |
/// | UiFactory<FooProps> Foo = uiFunction((props) {}, _$FooConfig);       | null   |
SimpleIdentifier? getGeneratedFactory(TopLevelVariableDeclaration node) {
  final type = node.variables.type;
  if (type != null && type is NamedType && type.name.name == 'UiFactory') {
    final initializer = node.variables.variables.first.initializer;
    if (initializer != null) {
      final name = node.variables.variables.first.name.name;
      final generatedName = r'_$' + name;
      if (initializer is SimpleIdentifier && initializer.name == generatedName)
        return initializer;
      return allDescendantsOfType<SimpleIdentifier>(initializer).firstWhereOrNull(
          (identifier) => identifier.name == generatedName);
    }
  }

  return null;
}

/// Returns whether or not [node] is a class or connected component factory declaration.
bool isClassOrConnectedComponentFactory(TopLevelVariableDeclaration node) =>
    getGeneratedFactory(node) != null;

/// Returns whether or not [node] is in the legacy boilerplate syntax.
bool isLegacyFactoryDecl(TopLevelVariableDeclaration node) {
  final annotation = node.metadata.firstWhereOrNull(
      (m) => m.toSource().startsWith('@Factory'));
  return isClassOrConnectedComponentFactory(node) && annotation != null;
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
///   Calling the utility like this:
///   ```
///   removeIgnoreComment(
///     node.beginToken.precedingComments,
///     'undefined_identifier',
///     yieldPatch,
///   );
///   ```
///   Will yield the following changes depending on the value of [comment]:
///
///   `// ignore: undefined_identifier` => entire comment will be removed
///
///   `// ignore: invalid_assignment, undefined_identifier` => `// ignore: invalid_assignment`
///
///   `// ignore: invalid_assignment` => `// ignore: invalid_assignment`
void removeIgnoreComment(
    Token? comment, String ignoreToRemove, YieldPatch yieldPatch) {
  ArgumentError.checkNotNull(ignoreToRemove, 'ignoreToRemove');
  if (comment == null) return;

  final lexeme = comment.lexeme.replaceAll(' ', '').toLowerCase();
  if (lexeme.startsWith('//ignore:')) {
    final ignoreList =
        lexeme.replaceFirst(RegExp('\/\/ignore\:'), '').split(',');
    if (ignoreList.contains(ignoreToRemove) && ignoreList.length == 1) {
      yieldPatch('', comment.previous?.end ?? comment.offset, comment.end);
    } else if (ignoreList.contains(ignoreToRemove)) {
      ignoreList.removeWhere((i) => i == ignoreToRemove);
      final newIgnoreComment = '// ignore: ${ignoreList.join(', ')}';
      yieldPatch(newIgnoreComment, comment.offset, comment.end);
    }
  }
}
