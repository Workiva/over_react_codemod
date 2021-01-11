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

/// Get the generated argument from [argList].
///
/// Used specifically to find the generated factory config in `uiFunction` /
/// `uiForwardRef` usages or the generated factory argument in `connect` usages.
///
/// Returns `null` if no generated argument found.
///
/// Example:
///
/// For Factory Configs:
/// | input                                                  | output      |
/// |--------------------------------------------------------|-------------|
/// | ((props) {}, $FooConfig)                               | $FooConfig  |
/// | ((props) {}, _$FooConfig as UiFactoryConfig<FooProps>) | _$FooConfig |
/// | ((props) {}, UiFactoryConfig())                        | null        |
///
/// For Connected Components:
/// | input                          | output |
/// |--------------------------------|--------|
/// | (_$Foo)                        | _$Foo  |
/// | (_$Foo as UiFactory<FooProps>) | _$Foo  |
/// | (Foo)                          | null   |
SimpleIdentifier getGeneratedArg(ArgumentList argList) {
  final args = argList.arguments;
  var prefixPattern = RegExp(r'_\$');
  dynamic generatedArg;

  // Find possible generated argument by location in `argList`.
  if (args.length == 1) {
    // Get possible generated argument from connect function invocations.
    final method =
        argList.thisOrAncestorOfType<FunctionExpressionInvocation>()?.function;
    if (method is MethodInvocation && method.methodName.name == 'connect') {
      generatedArg = args.first;
    }
  } else if (args.length == 2) {
    // Get possible generated factory config argument.
    generatedArg = args[1];
    prefixPattern = RegExp(r'_?\$[A-Za-z]*Config$');
  }

  // Find and return the generated argument if it exists.
  if (generatedArg is SimpleIdentifier) {
    return generatedArg.name.startsWith(prefixPattern) ? generatedArg : null;
  } else if (generatedArg is AsExpression) {
    final expression = generatedArg.expression;
    return expression is SimpleIdentifier &&
            expression.name.startsWith(prefixPattern)
        ? expression
        : null;
  }

  return null;
}
