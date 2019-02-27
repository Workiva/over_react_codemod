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

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

const _helpFlag = '--help';
const _helpFlagAbbr = '-h';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    FileQuery.dir(
      pathFilter: isDartFile,
      recursive: true,
    ),
    AsyncEmulator(),
    args: args,
    defaultYes: true,
    additionalHelpOutput:
        'A codemod that emulates Dart 1 async function timing in Dart 2 by adding delays to relevant async functions.',
  );

  if (exitCode > 0 ||
      args.contains(_helpFlag) ||
      args.contains(_helpFlagAbbr)) {
    return;
  }
}

class AsyncEmulator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  void visitFunctionExpression(FunctionExpression node) {
    node.visitChildren(this);

    final body = node.body;
    if (!body.isAsynchronous) {
      return;
    }

    if (isMain(node) || isTestMethodBlock(node)) {
      return;
    }

    if (body is BlockFunctionBody) {
      if (body.block.statements.isEmpty) {
        // Empty async function; timing is unaffected.
        return;
      } else if (body.block.statements.length == 1) {
        final statement = body.block.statements[0];
        if (statement is ReturnStatement &&
            isConstExpression(statement.expression)) {
          // Common case: a function that just returns a constant value,
          // which has no side effects and thus cannot affect timing.
          return;
        }
      }

      yieldPatch(body.block.leftBracket.end, body.block.leftBracket.end,
          '/* TODO d2_async */ await new Future(() {});');
    } else if (body is ExpressionFunctionBody) {
      if (isConstExpression(body.expression)) {
        // Common case: a function that just returns a constant value,
        // which has no side effects and thus cannot affect timing.
        return;
      }

      yieldPatch(body.keyword.offset, body.expression.end,
          '=> /* TODO d2_async */ new Future(() async => ${sourceFile.getText(body.expression.offset, body.expression.end)})');
    }
  }
}

bool isConstExpression(Expression expr) =>
    expr is BooleanLiteral ||
    expr is DoubleLiteral ||
    expr is IntegerLiteral ||
    expr is ListLiteral ||
    expr is MapLiteral ||
    expr is NullLiteral ||
    expr is StringLiteral ||
    (expr is InstanceCreationExpression && expr.isConst) ||
    (expr is TypedLiteral && expr.isConst);

FunctionDeclaration getFunctionDeclaration(FunctionExpression function) {
  final parent = function.parent;
  return parent is FunctionDeclaration ? parent : null;
}

bool isMain(FunctionExpression function) =>
    getFunctionDeclaration(function)?.name?.name == 'main';

bool isTestMethodBlock(FunctionExpression function) {
  final parent = function.parent;
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is InvocationExpression) {
      return const [
        'test',
        'setUp',
        'tearDown',
        'setUpAll',
        'tearDownAll',
      ].contains(grandparent.function.toSource());
    }
  }
  return false;
}

final testSource = '''
    asyncThing() async { }
    asyncThing() async { const foo = bar; }
    asyncThing() async { 'foo'; }
    asyncThing() async => 'foo';
    asyncThing() async {return 'foo';}
  
    asyncThing() async { foo(); await bar(); }
    
    asyncThing() async => await foo();
    asyncThing() async { await foo(); }
    asyncThing() async { return await foo(); }
    asyncThing() async { final string value = await foo(); }
    asyncThing() async { value = await foo(); }
    asyncThing() async { const String foo = 'bar'; await foo(); }
    
    asyncThing() async => foo(await bar());
    asyncThing() async { foo(await bar()); }
    asyncThing() async => foo && await bar();
    asyncThing() async { if (foo() && await bar()) {} }
    
    asyncThing() async { await foo(baz(), await bar()); }
    
    main() {
      test('async test', () async {
        await foo();
      });
      setUp(() async {
        await foo();
      });
      tearDown(() async {
        await foo();
      });
      setUpAll(() async {
        await foo();
      });
      tearDownAll(() async {
        await foo();
      });
    }
''';
