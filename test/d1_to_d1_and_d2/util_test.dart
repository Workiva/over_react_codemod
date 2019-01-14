@TestOn('vm')
import 'package:test/test.dart';

import 'package:codemod_over_react/src/constants.dart';
import 'package:codemod_over_react/src/d1_to_d1_and_d2/util.dart';

void main() {
  group('Utils for Dart1 -> Dart1/Dart2:', () {
    group('buildPropsCompanionClass()', () {
      testCompanionClassBuilder(buildPropsCompanionClass, propsMetaType);
    });

    group('buildStateCompanionClass()', () {
      testCompanionClassBuilder(buildStateCompanionClass, stateMetaType);
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
