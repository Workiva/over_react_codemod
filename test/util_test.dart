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
import 'package:over_react_codemod/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:over_react_codemod/src/constants.dart';

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
          }
        ''';

      final astNode = parseString(content: content).unit;
      int commentCount;

      setUp(() {
        commentCount = 0;
      });

      test('correctly iterates over all comments', () {
        commentCount = allComments(astNode.beginToken).length;

        expect(commentCount, 3);
      });

      test('only finds comments after the provided starting node', () {
        Token begin = astNode.beginToken;
        Token firstVar = begin;

        // Traverse the tokens until we get to var one.
        while (firstVar.value() != 'one' && !firstVar.isEof) {
          firstVar = firstVar.next;
        }

        commentCount = allComments(firstVar).length;

        expect(commentCount, 1);
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
