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

SimpleIdentifier getGeneratedArg(ArgumentList argList) {
  final args = argList.arguments;
  if(args.length == 1) {
    final method = argList.thisOrAncestorOfType<FunctionExpressionInvocation>()?.function;
    if (method is MethodInvocation && method.methodName.name == 'connect') {
      final generatedArg = args.first;
      return generatedArg is SimpleIdentifier && generatedArg.name.startsWith('_\$') ? generatedArg : null;
    }
  } else if(args.length == 2) {
    final configArg = args[1];
    if(configArg is SimpleIdentifier) {
      return configArg.name.startsWith(RegExp(r'_?\$[A-Za-z]*Config$')) ? configArg : null;
    }
    // else if(configArg is AsExpression) {
    //   final expression = configArg.expression;
    //   final type = configArg.type;
    //   return expression is SimpleIdentifier && expression.name.startsWith('_\$') && type is TypeName && type.name.name == 'UiFactory' ? expression : null;
    // }
  }
  return null;
}
