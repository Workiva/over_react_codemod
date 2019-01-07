@TestOn('vm')
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:codemod_over_react/src/constants.dart';
import 'package:codemod_over_react/src/util.dart';

void main() {
  group('Utils for all over_react codemods', () {
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
  });
}
