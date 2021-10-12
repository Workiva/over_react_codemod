import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:collection/collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';

void main() {
  group('component_usage', () {
    group('getComponentUsage', () {
      group(
          'accurately detects and collects information on usages of OverReact components:',
          () {
        group('components with no cascades:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              final source = '${builderSource.source}()';

              final expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              final componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);
            });
          });
        });

        group('components with cascades:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var cascadeSource = '${builderSource.source}..id = \'123\'';
              var source = '($cascadeSource)()';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(
                  componentUsage, builderSource, source, cascadeSource);
            });
          });
        });

        group('components with no cascade but extra parens:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var source = '(${builderSource.source})()';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);
            });
          });
        });

        group('components with no children:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var source = '${builderSource.source}()';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);

              expect(componentUsage!.childArgumentCount, 0);
              expect(componentUsage.hasVariadicChildren, false);
            });
          });
        });

        group('components with a single child:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var source = '${builderSource.source}("foo")';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);

              expect(componentUsage!.childArgumentCount, 1);
              expect(componentUsage.hasVariadicChildren, true);
            });
          });
        });

        group('components with more than one child:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var source = '${builderSource.source}("foo", "bar")';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);

              expect(componentUsage!.childArgumentCount, 2);
              expect(componentUsage.hasVariadicChildren, true);
            });
          });
        });

        group('components with list literal children:', () {
          buildersToTest.forEach((name, builderSource) {
            test('$name', () async {
              var source = '${builderSource.source}(["foo", "bar"])';

              var expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
              var componentUsage = getComponentUsage(expressionNode);

              checkComponentUsage(componentUsage, builderSource, source);

              expect(componentUsage!.childArgumentCount, 1);
              expect(componentUsage.hasVariadicChildren, false);
            });
          });
        });
      });

      test('returns null for invocations that aren\'t fluent interface usages',
          () {
        Future<void> verifyUsage(String source, String reason) async {
          final expressionNode = await parseInvocation(source);
          var componentUsage = getComponentUsage(expressionNode);
          expect(componentUsage, isNull, reason: '$source is $reason');
        }

        const {
          'Dom.h1()': 'not full invocation',
          'Foo()': 'not full invocation',
          'fooFactory()': 'not full invocation',
          'foo()': 'not a valid builder',
          'foo.bar()': 'not a valid builder',
          'foo()()': 'not a valid builder',
          '_foo()()': 'not a valid builder',
        }.forEach(verifyUsage);
      });
    });

    group('hasChildComponent', () {
      group('detects components within an argument list', () {
        group('when there is a single child that is a component', () {
          buildersToTest.forEach((name, builderSource) {
            test('and the child component uses a $name', () async {
              var childSource = '${builderSource.source}()';
              var source = 'SomeOtherComponent()($childSource)';

              final expressionNode = await parseInvocation(source);

              expect(hasChildComponent(expressionNode.argumentList), isTrue);
            });
          });
        });

        group('when there are multiple children, and only one is a component',
            () {
          buildersToTest.forEach((name, builderSource) {
            test('and the child component uses a $name', () async {
              var childSource = '${builderSource.source}()';
              var source =
                  'SomeOtherComponent()("other child 1", $childSource, "other child 2")';

              final expressionNode = await parseInvocation(source);

              expect(hasChildComponent(expressionNode.argumentList), isTrue);
            });
          });
        });
      });

      group('even when the components have any number of extra wrapping parens',
          () {
        buildersToTest.forEach((name, builderSource) {
          test('and the child component uses a $name', () async {
            var childSource = '${builderSource.source}()';
            var childSourceWithExtraParens = '((($childSource)))';
            var source = 'SomeOtherComponent()($childSourceWithExtraParens)';

            final expressionNode = await parseInvocation(source);

            expect(hasChildComponent(expressionNode.argumentList), isTrue);
          });
        });
      });

      test('returns false when there are only non-component arguments',
          () async {
        var source = 'SomeOtherComponent()(1, "non-component child", {})';
        final expressionNode = await parseInvocation(source);

        expect(hasChildComponent(expressionNode.argumentList), isFalse);
      });

      test(
          'returns false when there are nested components, but no top-level ones',
          () async {
        var source = 'SomeOtherComponent()([Foo()()])';
        final expressionNode = await parseInvocation(source);

        expect(hasChildComponent(expressionNode.argumentList), isFalse);
      });
    });

    group('identifyUsage', () {
      group('returns correct FluentComponentUsage usage when', () {
        buildersToTest.forEach((name, builderSource) {
          group('', () {
            final cascadeSource = '${builderSource.source}..id = \'123\'';
            final source = '($cascadeSource)(\'stringChild\')';
            late InvocationExpression expressionNode;

            setUpAll(() async {
              expressionNode = await parseInvocation(source,
                  imports: builderSource.imports, isResolved: true);
            });

            test('node is a $name which is already a component usage', () {
              final componentUsage = identifyUsage(expressionNode);
              checkComponentUsage(
                  componentUsage, builderSource, source, cascadeSource);
            });

            group('node inside $name', () {
              test('is props cascade expression', () {
                final cascadeExpression = getComponentUsage(expressionNode)
                    ?.cascadeExpression
                    ?.cascadeSections
                    .firstOrNull;
                expect(cascadeExpression?.toSource(), '..id = \'123\'');
                final componentUsage = identifyUsage(cascadeExpression);
                checkComponentUsage(
                    componentUsage, builderSource, source, cascadeSource);
              });

              test('is a child should return null', () {
                final child = expressionNode.argumentList.arguments.firstOrNull;
                expect(child?.toSource(), '\'stringChild\'');
                final componentUsage = identifyUsage(child);
                expect(componentUsage, isNull);
              });
            });
          });

          group('a $name is a child of another component', () {
            final cascadeSource = '${builderSource.source}..id = \'123\'';
            final childSource = '($cascadeSource)(\'stringChild\')';
            final nestedSource = 'Bar()($childSource)';
            late InvocationExpression expressionNode;
            late InvocationExpression childExpression;

            setUpAll(() async {
              expressionNode = await parseInvocation(
                nestedSource,
                imports: builderSource.imports,
                isResolved: true,
              );

              expect(
                  expressionNode.argumentList.arguments.firstOrNull, isNotNull);
              expect(expressionNode.argumentList.arguments.firstOrNull,
                  isA<InvocationExpression>());
              childExpression = expressionNode
                  .argumentList.arguments.firstOrNull as InvocationExpression;
              expect(childExpression.toSource(), childSource);
            });

            test('and node is the parent component', () {
              final componentUsage = identifyUsage(expressionNode);
              checkComponentUsage(
                  componentUsage,
                  BuilderTestCase(
                    source: 'Bar()',
                    imports: '',
                    componentName: 'Bar',
                    isDom: false,
                    isSvg: false,
                  ),
                  nestedSource);
            });

            test('and node is the child component', () {
              final componentUsage = identifyUsage(childExpression);
              checkComponentUsage(
                  componentUsage, builderSource, childSource, cascadeSource);
            });

            group('and the node inside the child component', () {
              test('is props cascade expression', () {
                final cascadeExpression = getComponentUsage(childExpression)
                    ?.cascadeExpression
                    ?.cascadeSections
                    .firstOrNull;
                expect(cascadeExpression?.toSource(), '..id = \'123\'');
                final componentUsage = identifyUsage(cascadeExpression);
                checkComponentUsage(
                    componentUsage, builderSource, childSource, cascadeSource);
              });

              test('is a child should return null', () {
                final child =
                    childExpression.argumentList.arguments.firstOrNull;
                expect(child?.toSource(), '\'stringChild\'');
                final componentUsage = identifyUsage(child);
                expect(componentUsage, isNull);
              });
            });
          });
        });
      });

      group('returns null when node has no parent component usage', () {
        {
          const source = /*language=dart*/ r'''
            class Foo {
              void foo() {
                var a = 'abc';
              }
            }
          ''';

          test('and node is a class declaration', () {
            final classDecl = parseAndGetNode<ClassDeclaration>(source);
            final componentUsage = identifyUsage(classDecl);
            expect(componentUsage, isNull);
          });

          test('and node is a method declaration', () {
            final methodDecl = parseAndGetNode<MethodDeclaration>(source);
            final componentUsage = identifyUsage(methodDecl);
            expect(componentUsage, isNull);
          });

          test('and node is a variable declaration', () {
            final variableDecl = parseAndGetNode<VariableDeclaration>(source);
            final componentUsage = identifyUsage(variableDecl);
            expect(componentUsage, isNull);
          });
        }

        test('and node is an invocation expression', () async {
          final expressionNode =
              await parseInvocation('Foo.foo(() => \'abc\')');
          final componentUsage = identifyUsage(expressionNode);
          expect(componentUsage, isNull);
        });

        test('and node is an argument of an invocation expression', () async {
          final expressionNode =
              await parseInvocation('Foo.foo(() => \'abc\')');
          final arg = expressionNode.argumentList.arguments.firstOrNull;
          expect(arg, isNotNull);
          final componentUsage = identifyUsage(arg);
          expect(componentUsage, isNull);
        });
      });
    });

    group('FluentComponentUsage', () {
      group('cascaded helpers', () {
        late FluentComponentUsage usage;

        setUpAll(() async {
          usage = getComponentUsage(await parseInvocation('''
              (Foo()
                ..cascadedProp1 = null
                ..cascadedGetter1
                ..["cascadedIndexAssignment1"] = null
                ..["cascadedIndexRead1"]
                ..cascadedMethodInvocation1()
                // Don't group the same types of nodes together so that 
                // we can verify the order in cascadedMembers (i.e., put all
                // the "2"s together instead of right next to their "1"s).
                ..cascadedProp2 = null
                ..cascadedGetter2
                ..["cascadedIndexAssignment2"] = null
                ..["cascadedIndexRead2"]
                ..cascadedMethodInvocation2(null)
              )()
          '''))!;
        });

        group('return the expected values for different types of cascades', () {
          test('cascadedProps', () {
            expect(usage.cascadedProps, [
              isA<PropAssignment>().havingStringName('cascadedProp1'),
              isA<PropAssignment>().havingStringName('cascadedProp2'),
            ]);
          });

          test('cascadedGetters', () {
            expect(usage.cascadedGetters, [
              isA<PropAccess>().havingStringName('cascadedGetter1'),
              isA<PropAccess>().havingStringName('cascadedGetter2'),
            ]);
          });

          test('cascadedIndexAssignments', () {
            expect(usage.cascadedIndexAssignments, [
              isA<IndexPropAssignment>()
                  .havingIndexValueSource('"cascadedIndexAssignment1"'),
              isA<IndexPropAssignment>()
                  .havingIndexValueSource('"cascadedIndexAssignment2"'),
            ]);
          });

          test('cascadedMethodInvocations', () {
            expect(usage.cascadedMethodInvocations, [
              isA<BuilderMethodInvocation>()
                  .havingStringName('cascadedMethodInvocation1'),
              isA<BuilderMethodInvocation>()
                  .havingStringName('cascadedMethodInvocation2'),
            ]);
          });
        });

        test(
            'cascadedMembers returns all values for different types of cascades,'
            ' in the order they appeared in the original source', () {
          expect(usage.cascadedMembers, [
            isA<PropAssignment>().havingStringName('cascadedProp1'),
            isA<PropAccess>().havingStringName('cascadedGetter1'),
            isA<IndexPropAssignment>()
                .havingIndexValueSource('"cascadedIndexAssignment1"'),
            isA<BuilderMemberAccess>().havingSource('..["cascadedIndexRead1"]'),
            isA<BuilderMethodInvocation>()
                .havingStringName('cascadedMethodInvocation1'),
            isA<PropAssignment>().havingStringName('cascadedProp2'),
            isA<PropAccess>().havingStringName('cascadedGetter2'),
            isA<IndexPropAssignment>()
                .havingIndexValueSource('"cascadedIndexAssignment2"'),
            isA<BuilderMemberAccess>().havingSource('..["cascadedIndexRead2"]'),
            isA<BuilderMethodInvocation>()
                .havingStringName('cascadedMethodInvocation2'),
          ]);
          expect(usage.cascadedMembers, hasLength(usage.cascadeSections.length),
              reason: 'all cascade sections should map to a cascaded member');
        });
      });
    });
  });
}

extension on TypeMatcher<BuilderMemberAccess> {
  Matcher havingSource(dynamic matcher) =>
      having((p) => p.node.toSource(), 'node.toSource()', matcher);
}

extension on TypeMatcher<PropAssignment> {
  Matcher havingStringName(dynamic matcher) =>
      having((p) => p.name.name, 'name.name', matcher);
}

extension on TypeMatcher<PropAccess> {
  Matcher havingStringName(dynamic matcher) =>
      having((p) => p.name.name, 'name.name', matcher);
}

extension on TypeMatcher<BuilderMethodInvocation> {
  Matcher havingStringName(dynamic matcher) =>
      having((p) => p.methodName.name, 'methodName.name', matcher);
}

extension on TypeMatcher<IndexPropAssignment> {
  Matcher havingIndexValueSource(dynamic matcher) =>
      having((p) => p.index.toSource(), 'index.toSource', matcher);
}

void checkComponentUsage(FluentComponentUsage? componentUsage,
    BuilderTestCase builderSource, String source,
    [String? cascadeSource]) {
  expect(componentUsage, isNotNull);
  componentUsage!;
  expect(componentUsage.builder.toSource(), builderSource.source);
  expect(componentUsage.node.toSource(), source);
  expect(componentUsage.componentName, builderSource.componentName);
  expect(componentUsage.isDom, builderSource.isDom);
  expect(componentUsage.isSvg, builderSource.isSvg);
  expect(componentUsage.cascadeExpression?.toSource(), cascadeSource ?? isNull);
}

class BuilderTestCase {
  String source;
  String imports;
  String componentName;
  bool isDom;
  bool isSvg;

  BuilderTestCase({
    required this.source,
    required this.imports,
    required this.componentName,
    required this.isDom,
    required this.isSvg,
  });
}

const fooComponents = /*language=dart*/ r'''
import 'package:over_react/over_react.dart';
UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier, invalid_assignment
mixin FooProps on UiProps {}
class FooComponent extends UiComponent2<FooProps> {
  @override
  void render() {}
}
UiFactory<BarProps> Bar = _$Bar; // ignore: undefined_identifier, invalid_assignment
mixin BarProps on UiProps {}
class BarComponent extends UiComponent2<BarProps> {
  @override
  void render() {}
}
FooProps getFooBuilder() => Foo();
FooProps getBuilderForFoo() => Foo();
''';

/// An enumeration of all the supported OverReact component builders that can be detected
/// using [FluentComponentUsage], and used to target code when formatting.
///
/// Keys are descriptions, and values are [BuilderTestCase]s.
final buildersToTest = {
  'DOM factory': BuilderTestCase(
    source: 'Dom.h1()',
    imports: fooComponents,
    componentName: 'Dom.h1',
    isDom: true,
    isSvg: false,
  ),
  'DOM factory w/ SVG props': BuilderTestCase(
    source: 'Dom.circle()',
    imports: fooComponents,
    componentName: 'Dom.circle',
    isDom: true,
    isSvg: true,
  ),
  'DOM factory w/ namespaced import': BuilderTestCase(
    source: 'foo_bar.Dom.h1()',
    imports:
        'import \'package:over_react/over_react.dart\' as foo_bar;$fooComponents',
    componentName: 'Dom.h1',
    isDom: true,
    isSvg: false,
  ),
  'component factory': BuilderTestCase(
    source: 'Foo()',
    imports: fooComponents,
    componentName: 'Foo',
    isDom: false,
    isSvg: false,
  ),
  'component factory w/ namespaced import': BuilderTestCase(
    source: 'foo_bar.ErrorBoundary()',
    imports:
        'import \'package:over_react/components.dart\' as foo_bar;$fooComponents',
    componentName: 'ErrorBoundary',
    isDom: false,
    isSvg: false,
  ),
  'custom builder function (ending in keyword)': BuilderTestCase(
    source: 'getFooBuilder()',
    imports: fooComponents,
    componentName: 'Foo',
    isDom: false,
    isSvg: false,
  ),
  'custom builder function (not ending in keyword)': BuilderTestCase(
    source: 'getBuilderForFoo()',
    imports: fooComponents,
    componentName: 'Foo',
    isDom: false,
    isSvg: false,
  ),
};

/// Returns [expression] parsed as AST.
///
/// This is accomplished it by including the [expression] as a statement within a wrapper function
/// with any necessary [imports] at the top of the source. As a result, the offset of the
/// returned expression will not be 0.
///
/// To return resolved AST, set [isResolved] to true.
///
/// Throws if [expression] is not an [InvocationExpression].
Future<InvocationExpression> parseInvocation(
  String expression, {
  String imports = '',
  bool isResolved = false,
}) async {
  CompilationUnit unit;
  final source = '''
    $imports
    void wrapperFunction() {
      $expression;
    }
  ''';
  final fileContext =
      await SharedAnalysisContext.overReact.resolvedFileContextForTest(source,
          // We don't want to get the resolved unit if `isResolve = false`,
          // since it may fail.
          preResolveFile: false,
          throwOnAnalysisErrors: false);
  if (isResolved) {
    final result = await fileContext.getResolvedUnit();
    unit = result!.unit!;
  } else {
    unit = fileContext.getUnresolvedUnit();
  }
  final parsedFunction =
      unit.childEntities.whereType<FunctionDeclaration>().last;
  final body = parsedFunction.functionExpression.body as BlockFunctionBody;
  final statement = body.block.statements.single as ExpressionStatement;
  final invocationExpression = statement.expression;
  if (invocationExpression is InvocationExpression) {
    return invocationExpression;
  } else {
    throw ArgumentError.value(expression, 'expression',
        'was not a InvocationExpression; was $invocationExpression');
  }
}

/// Parses [dartSource] and returns the unresolved AST, throwing if there are any syntax errors.
CompilationUnit parseAndGetUnit(String dartSource) {
  final result = parseString(
    content: dartSource,
    throwIfDiagnostics: false,
    path: 'dart source from string',
  );
  // `throwIfDiagnostics: true` throws, but does not include the actual errors in the exception.
  // We'll handle throwing when there are errors.
  if (result.errors.isNotEmpty) {
    throw ArgumentError('Parse errors in source:\n${result.errors.join('\n')}');
  }
  return result.unit;
}

/// Returns a lazy iterable of all descendants of [node], in breadth-first order.
Iterable<AstNode> allDescendants(AstNode node) sync* {
  final nodesQueue = Queue<AstNode>()..add(node);
  while (nodesQueue.isNotEmpty) {
    final current = nodesQueue.removeFirst();

    for (final child in current.childEntities) {
      if (child is AstNode) {
        yield child;
        nodesQueue.add(child);
      }
    }
  }
}

/// Returns a lazy iterable of all descendants of [node] of type [T], in breadth-first order.
Iterable<T> allDescendantsOfType<T extends AstNode>(AstNode node) =>
    allDescendants(node).whereType<T>();

/// Parses [dartSource] and returns the first node of type [T].
///
/// Useful for easily creating a node of a certain type for tests.
///
/// Throws if a matching node is not found.
///
/// Example:
/// ```dart
/// final body = parseAndGetNode<BlockFunctionBody>(r'''
///   myFunction() {
///     // ...
///   }
/// ''');
/// ```
T parseAndGetNode<T extends AstNode>(String dartSource) =>
    allDescendantsOfType<T>(parseAndGetUnit(dartSource)).first;