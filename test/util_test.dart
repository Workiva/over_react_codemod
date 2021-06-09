// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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

@TestOn('vm')
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:over_react_codemod/src/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:over_react_codemod/src/util.dart';

void main() {
  group('Utils', () {
    group('buildIgnoreComment()', () {
      test('constInitializedWithNonConstantValue', () {
        expect(buildIgnoreComment(constInitializedWithNonConstantValue: true),
            '// ignore: const_initialized_with_non_constant_value');
      });

      test('mixinOfNonClass', () {
        expect(buildIgnoreComment(mixinOfNonClass: true),
            '// ignore: mixin_of_non_class');
      });

      test('undefinedClass', () {
        expect(buildIgnoreComment(undefinedClass: true),
            '// ignore: undefined_class');
      });

      test('undefinedIdentifier', () {
        expect(buildIgnoreComment(undefinedIdentifier: true),
            '// ignore: undefined_identifier');
      });

      test('uriHasNotBeenGenerated', () {
        expect(buildIgnoreComment(uriHasNotBeenGenerated: true),
            '// ignore: uri_has_not_been_generated');
      });

      test('multiple', () {
        expect(buildIgnoreComment(mixinOfNonClass: true, undefinedClass: true),
            '// ignore: mixin_of_non_class, undefined_class');
      });
    });

    group('buildPropsCompanionClass()', () {
      testCompanionClassBuilder(buildPropsCompanionClass, propsMetaType);
    });

    group('buildStateCompanionClass()', () {
      testCompanionClassBuilder(buildStateCompanionClass, stateMetaType);
    });

    group('convertPartOfUriToRelativePath()', () {
      test('package uri', () {
        final expectedTarget = p.canonicalize('./lib/src/bar.dart');

        // Package URI targeting the above file.
        final uri1 = Uri.parse('package:foo/src/bar.dart');
        final converted1 = convertPartOfUriToRelativePath(null, uri1);
        expect(converted1, expectedTarget);

        // Same file, but a different route there. Verifies that returned paths
        // are canonicalized.
        final uri2 = Uri.parse('package:foo/src/baz/../bar.dart');
        final converted2 = convertPartOfUriToRelativePath(null, uri2);
        expect(converted2, expectedTarget);
      });

      test('relative uri', () {
        final expectedTarget = p.canonicalize('./lib/src/bar.dart');

        final libraryPath1 = './lib/foo.dart';
        final uri1 = Uri.parse('./src/bar.dart');
        final converted1 = convertPartOfUriToRelativePath(libraryPath1, uri1);
        expect(converted1, expectedTarget);

        final libraryPath2 = './lib/src/sub/baz.dart';
        final uri2 = Uri.parse('../bar.dart');
        final converted2 = convertPartOfUriToRelativePath(libraryPath2, uri2);
        expect(converted2, expectedTarget);
      });
    });

    group('doesNotUseOverReact()', () {
      test('returns true when no over_react annotations found', () {
        final contents = '''library foo;
@deprecated
void foo() {}''';
        expect(doesNotUseOverReact(contents), isTrue);
      });

      test('returns true when over_react annotation is in a comment', () {
        final contents = '''library foo;
/// Doc comment with example of over_react props class:
///     @Props()
///     class FooProps extends UiProps {}
void overReactExample() {}''';
        expect(doesNotUseOverReact(contents), isTrue);
      });

      for (final annotation in overReactAnnotationNames) {
        test('returns false when @$annotation() found', () {
          final contents = '''library foo;
@$annotation(bar: true) var baz;''';
          expect(doesNotUseOverReact(contents), isFalse);
        });
      }

      test('returns a false negative when annotation found in a string', () {
        final contents = '''var multiLineStr = \'\'\'line1
@Factory() line2\'\'\';''';
        expect(doesNotUseOverReact(contents), isFalse);
      });
    });

    group('generateNewVersionRange()', () {
      group('updates correctly with a basic range', () {
        sharedGenerateNewVersionRangeTests(
          currentRange: VersionConstraint.parse('>=0.5.0 <3.0.0'),
          currentRangeWithHigherMinBound:
              VersionConstraint.parse('>=1.5.0 <3.0.0'),
          targetRange: VersionConstraint.parse('>=1.0.0 <4.0.0'),
          expectedMixedRange: VersionConstraint.parse('>=1.5.0 <4.0.0'),
        );
      });

      group('updates correctly with an open ended target range', () {
        sharedGenerateNewVersionRangeTests(
          currentRange: VersionConstraint.parse('>=1.0.0 <2.0.0'),
          currentRangeWithHigherMinBound:
              VersionConstraint.parse('>=1.2.0 <2.0.0'),
          targetRange: VersionConstraint.parse('>=1.0.0'),
          expectedMixedRange: VersionConstraint.parse('>=1.2.0'),
        );
      });

      group('updates correctly with an open ended current range', () {
        sharedGenerateNewVersionRangeTests(
          currentRange: VersionConstraint.parse('>=1.0.0'),
          currentRangeWithHigherMinBound: VersionConstraint.parse('>=1.2.0'),
          targetRange: VersionConstraint.parse('>=1.0.0 <2.0.0'),
          expectedMixedRange: VersionConstraint.parse('>=1.2.0 <2.0.0'),
        );
      });
    });

    group('friendlyVersionConstraint()', () {
      String friendlyFromString(String constraintSource) =>
          friendlyVersionConstraint(VersionConstraint.parse(constraintSource));

      test('returns a caret representation of a range if possible', () {
        expect(friendlyFromString('^1.0.0'), '^1.0.0');
        expect(friendlyFromString('>=1.0.0 <2.0.0'), '^1.0.0');
        expect(friendlyFromString('>=1.1.0 <2.0.0'), '^1.1.0');
        expect(friendlyFromString('>=1.1.0-alpha <2.0.0'), '^1.1.0-alpha');
      });

      test(
          'returns the version constraint\'s toString if caret syntax cannot be used',
          () {
        expect(friendlyFromString('>1.0.0 <2.0.0'), '>1.0.0 <2.0.0');
        expect(friendlyFromString('>=1.0.0 <3.0.0'), '>=1.0.0 <3.0.0');
        expect(friendlyFromString('>=1.0.0 <1.5.0'), '>=1.0.0 <1.5.0');
        // Edge cases
        expect(friendlyFromString('any'), 'any');
        expect(friendlyVersionConstraint(VersionConstraint.empty),
            VersionConstraint.empty.toString());
      });
    });

    group('isAssociatedWithComponent2()', () {
      group('returns true', () {
        test('if component extending UiComponent2 is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), true);
          });
        });

        test('if Component2 extending a non-base class is in the same file',
            () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends SomeClassName<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), true);
          });
        });
      });

      group('returns false', () {
        test('if component extending UiComponent is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
            
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });

        test('if Component extending a non-base class is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
            
            @Component()
            class FooComponent extends SomeClassName<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });

        test('if there is no component class in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });
      });
    });

    group('mightNeedYamlEscaping()', () {
      group('returns true if the value', () {
        test('starts with ">"', () {
          expect(mightNeedYamlEscaping(">=4.0.0"), isTrue);
        });
      });

      group('returns false if the value', () {
        test('does not start with a >', () {
          expect(mightNeedYamlEscaping("^4.0.0"), isFalse);
        });

        test('starts with "<"', () {
          expect(mightNeedYamlEscaping("<4.0.0"), isFalse);
        });

        test('is an explicit value', () {
          expect(mightNeedYamlEscaping("4.0.0"), isFalse);
        });
      });
    });

    group('renamePropsOrStateClass()', () {
      test('public', () {
        expect(renamePropsOrStateClass('Foo'), r'_$Foo');
      });

      test('private', () {
        expect(renamePropsOrStateClass('_Foo'), r'_$_Foo');
      });

      test('public already renamed', () {
        expect(renamePropsOrStateClass(r'_$Foo'), r'_$Foo');
      });

      test('private already renamed', () {
        expect(renamePropsOrStateClass(r'_$_Foo'), r'_$_Foo');
      });
    });

    group('shouldUpdateVersionRange() updates correctly', () {
      test('when the current dependency uses "any" as the version', () {
        expect(
          shouldUpdateVersionRange(
            constraint: VersionConstraint.parse('any'),
            targetConstraint: VersionConstraint.parse('^5.0.0'),
          ),
          isFalse,
        );
      });

      group('when the current dependency uses the caret syntax ', () {
        test('and the target uses caret syntax', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('^4.0.0'),
                  targetConstraint: VersionConstraint.parse('^5.0.0')),
              isTrue);
        });

        test('and the target uses a range', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('^4.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <6.0.0')),
              isTrue);
        });
      });

      group('when the current dependency uses a range ', () {
        test('and the range has no specified max', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=4.0.0'),
                  targetConstraint: VersionConstraint.parse('^5.0.0')),
              isTrue);
        });

        test('and the target uses caret syntax', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=4.0.0 <5.0.0'),
                  targetConstraint: VersionConstraint.parse('^5.0.0')),
              isTrue);
        });

        test('and the target uses a range', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=4.0.0 <5.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <6.0.0')),
              isTrue);
        });
      });

      group('when shouldIgnoreMin is true ', () {
        test('and the current min is higher than the target min', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=5.5.0 <6.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <6.0.0'),
                  shouldIgnoreMin: true),
              isTrue);
        });

        test('and the target max is higher than the current max', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=5.5.0 <6.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <7.0.0'),
                  shouldIgnoreMin: true),
              isTrue);
        });
      });

      group('when shouldIgnoreMin is false ', () {
        test('and the current min is higher than the target min', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=5.5.0 <6.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <6.0.0')),
              isFalse);
        });

        test('and the target max is higher than the current max', () {
          expect(
              shouldUpdateVersionRange(
                  constraint: VersionConstraint.parse('>=5.5.0 <6.0.0'),
                  targetConstraint: VersionConstraint.parse('>=5.0.0 <7.0.0')),
              isTrue);
        });
      });

      test('and the current max is higher than the target max', () {
        expect(
            shouldUpdateVersionRange(
                constraint: VersionConstraint.parse('>=5.0.0 <7.0.0'),
                targetConstraint: VersionConstraint.parse('>=5.0.0 <6.0.0')),
            isFalse);
      });
    });

    group('stripPrivateGeneratedPrefix()', () {
      test('with prefix', () {
        expect(stripPrivateGeneratedPrefix(r'_$Foo'), 'Foo');
      });

      test('without prefix', () {
        expect(stripPrivateGeneratedPrefix(r'Foo'), 'Foo');
      });

      test('with prefix not at beginning', () {
        expect(stripPrivateGeneratedPrefix(r'Foo_$Bar'), r'Foo_$Bar');
      });
    });

    group('hasComment()', () {
      final content = '''
          main() { // Comment0
            // Comment1
            // Comment2
            var one;
            var two;

            // Comment3
          }
        ''';

      final sourceFile = SourceFile.fromString(content);
      final astNode = parseString(content: content).unit;

      test('correctly finds a comment', () {
        expect(hasComment(astNode, sourceFile, 'Comment0'), isTrue);
      });

      test('breaks after finding first comment', () {
        expect(hasComment(astNode, sourceFile, 'Comment1'), isFalse);
      });

      test('only finds a comment within one line of the provided node', () {
        expect(hasComment(astNode, sourceFile, 'Comment2'), isFalse);
      });
    });

    group('allComments()', () {
      final content = '''
          main() {
            // Comment1
            // Comment2
            var one;
            var two;

            // Comment3
          } // Comment4
        ''';

      final astNode = parseString(content: content).unit;
      int commentCount;

      setUp(() {
        commentCount = 0;
      });

      test('correctly iterates over all comments', () {
        commentCount = allComments(astNode.beginToken).length;

        expect(commentCount, 4);
      });

      test('only finds comments after the provided starting node', () {
        Token begin = astNode.beginToken;
        Token firstVar = begin;

        // Traverse the tokens until we get to var one.
        while (firstVar.value() != 'one' && !firstVar.isEof) {
          firstVar = firstVar.next;
        }

        commentCount = allComments(firstVar).length;

        expect(commentCount, 2);
      });
    });

    group('allCommentsForNode()', () {
      CompilationUnitMember parseAndGetSingle(String source) =>
          parseString(content: source).unit.declarations.single;

      test('returns all comments for a node', () {
        expect(allCommentsForNode(parseAndGetSingle('''
          // Some comment
          int node;
        ''')).map((comment) => comment.toString()).toList(), [
          '// Some comment',
        ]);
      });

      test('handles nodes with doc comments properly', () {
        // It's important to test both orders due to the way
        // doc comments are included in the node.

        expect(allCommentsForNode(parseAndGetSingle('''
          /// Doc comment
          // other comment
          int node;
        ''')).map((comment) => comment.toString()).toList(), [
          '/// Doc comment',
          '// other comment',
        ]);

        expect(allCommentsForNode(parseAndGetSingle('''
          // other comment
          /// Doc comment
          int node;
        ''')).map((comment) => comment.toString()).toList(), [
          '// other comment',
          '/// Doc comment',
        ]);
      });

      test('handles mixed comment types properly', () {
        expect(allCommentsForNode(parseAndGetSingle('''
          // single line comment
          /* multiline comment */
          int node;
        ''')).map((comment) => comment.toString()).toList(), [
          '// single line comment',
          '/* multiline comment */',
        ]);

        expect(allCommentsForNode(parseAndGetSingle('''
          /* multiline comment */
          // single line comment
          int node;
        ''')).map((comment) => comment.toString()).toList(), [
          '/* multiline comment */',
          '// single line comment',
        ]);
      });
    });

    group('hasParseErrors()', () {
      test('when sourceText contains invalid code', () {
        expect(
          hasParseErrors('a = 1;'),
          isTrue,
        );
      });

      test('when sourceText contains valid code', () {
        expect(
          hasParseErrors('final a = 1;'),
          isFalse,
        );
      });
    });

    group('allDescendants()', () {
      TopLevelVariableDeclaration parseAndGetSingle(String source) =>
          parseString(content: source)
              .unit
              .declarations
              .whereType<TopLevelVariableDeclaration>()
              .single;

      test('returns all descendants for a node', () {
        final node = parseAndGetSingle('''
          UiFactory<FooProps> Foo = castUiFactory(_\$Foo); // ignore: undefined_identifier
        ''');

        expect(
            allDescendants(node).toList(),
            unorderedEquals([
              isA<VariableDeclarationList>().having(
                (node) => node.toSource(),
                'string value',
                'UiFactory<FooProps> Foo = castUiFactory(_\$Foo)',
              ),
              isA<VariableDeclaration>().having(
                (node) => node.toSource(),
                'string value',
                'Foo = castUiFactory(_\$Foo)',
              ),
              isA<TypeName>()
                  .having((node) => node.name.name, 'name', 'UiFactory'),
              isA<TypeName>()
                  .having((node) => node.name.name, 'name', 'FooProps'),
              isA<MethodInvocation>().having((node) => node.methodName.name,
                  'methodName', 'castUiFactory'),
              isA<TypeArgumentList>().having(
                  (node) => node.arguments.toList(), 'arguments', [
                isA<TypeName>()
                    .having((node) => node.name.name, 'name', 'FooProps')
              ]),
              isA<ArgumentList>().having(
                  (node) => node.arguments.toList(), 'arguments', [
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', '_\$Foo')
              ]),
              isA<SimpleIdentifier>()
                  .having((node) => node.name, 'name', 'Foo'),
              isA<SimpleIdentifier>()
                  .having((node) => node.name, 'name', 'UiFactory'),
              isA<SimpleIdentifier>()
                  .having((node) => node.name, 'name', 'FooProps'),
              isA<SimpleIdentifier>()
                  .having((node) => node.name, 'name', '_\$Foo'),
              isA<SimpleIdentifier>()
                  .having((node) => node.name, 'name', 'castUiFactory'),
            ]));
      });

      test('returns empty list when input is null', () {
        expect(allDescendants(null).toList(), isEmpty);
      });

      test('returns empty list when input has no descendants', () {
        final node = parseAndGetSingle('''
          UiFactory<FooProps> Foo = castUiFactory(_\$Foo); // ignore: undefined_identifier
        ''').variables.variables.first.name;

        expect(allDescendants(node).toList(), isEmpty);
      });
    });

    group('allDescendantsOfType()', () {
      TopLevelVariableDeclaration parseAndGetSingle(String source) =>
          parseString(content: source)
              .unit
              .declarations
              .whereType<TopLevelVariableDeclaration>()
              .single;

      group('returns all descendants of the specified type for a node', () {
        final node = parseAndGetSingle('''
          UiFactory<FooProps> Foo = castUiFactory(_\$Foo); // ignore: undefined_identifier
        ''');

        test('when there are many descendants of a type', () {
          expect(
              allDescendantsOfType<SimpleIdentifier>(node).toList(),
              unorderedEquals([
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', 'Foo'),
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', 'UiFactory'),
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', 'FooProps'),
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', '_\$Foo'),
                isA<SimpleIdentifier>()
                    .having((node) => node.name, 'name', 'castUiFactory'),
              ]));
        });

        test('when there is one descendant of a type', () {
          expect(
              allDescendantsOfType<MethodInvocation>(node).toList(),
              unorderedEquals([
                isA<MethodInvocation>().having((node) => node.methodName.name,
                    'methodName', 'castUiFactory'),
              ]));
        });

        test('when there are no descendants of a type', () {
          expect(
              allDescendantsOfType<MethodDeclaration>(node).toList(), isEmpty);
        });
      });

      test('when input is null', () {
        expect(allDescendantsOfType<SimpleIdentifier>(null).toList(), isEmpty);
      });

      test('when input has no descendants', () {
        final node = parseAndGetSingle('''
          UiFactory<FooProps> Foo = castUiFactory(_\$Foo); // ignore: undefined_identifier
        ''').variables.variables.first.name;

        expect(allDescendantsOfType<SimpleIdentifier>(node).toList(), isEmpty);
      });
    });
  });
}

void testCompanionClassBuilder(CompanionBuilder builder, String metaType) {
  final mixinIgnoreComment = '// ignore: mixin_of_non_class, undefined_class';
  final metaIgnoreComment =
      '// ignore: const_initialized_with_non_constant_value, undefined_class, undefined_identifier';

  test(r'public class: Foo', () {
    expect(builder(r'Foo'), '''

// This will be removed once the transition to Dart 2 is complete.
class Foo extends _\$Foo
    with
        $mixinIgnoreComment
        _\$FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaForFoo;
}
''');
  });

  test(r'public class: _$Foo', () {
    expect(builder(r'_$Foo'), '''

// This will be removed once the transition to Dart 2 is complete.
class Foo extends _\$Foo
    with
        $mixinIgnoreComment
        _\$FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaForFoo;
}
''');
  });

  test(r'private class: _Foo', () {
    expect(builder(r'_Foo'), '''

// This will be removed once the transition to Dart 2 is complete.
class _Foo extends _\$_Foo
    with
        $mixinIgnoreComment
        _\$_FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaFor_Foo;
}
''');
  });

  test(r'private class: _$_Foo', () {
    expect(builder(r'_$_Foo'), '''

// This will be removed once the transition to Dart 2 is complete.
class _Foo extends _\$_Foo
    with
        $mixinIgnoreComment
        _\$_FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaFor_Foo;
}
''');
  });

  test('with comment prefix', () {
    expect(builder(r'Foo', commentPrefix: 'AF-123: '), '''

// AF-123: This will be removed once the transition to Dart 2 is complete.
class Foo extends _\$Foo
    with
        $mixinIgnoreComment
        _\$FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaForFoo;
}
''');
  });

  test('with annotations', () {
    expect(builder(r'Foo', annotations: '@Bar(true)\n@deprecated'), '''

@Bar(true)
@deprecated
// This will be removed once the transition to Dart 2 is complete.
class Foo extends _\$Foo
    with
        $mixinIgnoreComment
        _\$FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaForFoo;
}
''');
  });

  test('with doc comment', () {
    expect(builder(r'Foo', docComment: '/// Line 1\n/// Line 2'), '''

/// Line 1
/// Line 2
// This will be removed once the transition to Dart 2 is complete.
class Foo extends _\$Foo
    with
        $mixinIgnoreComment
        _\$FooAccessorsMixin {
  $metaIgnoreComment
  static const $metaType meta = _\$metaForFoo;
}
''');
  });
}

void sharedGenerateNewVersionRangeTests(
    {@required VersionRange currentRange,
    @required VersionRange currentRangeWithHigherMinBound,
    @required VersionRange targetRange,
    @required VersionRange expectedMixedRange}) {
  group('', () {
    test('', () {
      expect(generateNewVersionRange(currentRange, targetRange), targetRange);
    });

    test(
        'when the current range lower bound is higher than the target '
        'range lower bound', () {
      expect(
          generateNewVersionRange(currentRangeWithHigherMinBound, targetRange),
          expectedMixedRange);
    });
  });
}
