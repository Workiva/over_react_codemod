from ..context import with_props_or_state_mixins
from .util import CodemodPatchTestCase

import codemod
import mock
import re
import unittest


class TestWithPropsOrStateMixinsMetaSuggestor(CodemodPatchTestCase):

    @property
    def suggestor(self):
        return with_props_or_state_mixins.with_props_and_state_mixins_suggestor

    def test_empty(self):
        self.suggest('')
        self.assert_no_patches_suggested()

    def test_no_match(self):
        self.suggest('''library foo;

@Props()
class FooProps extends UiProps {
  String value;
}
''')
        self.assert_no_patches_suggested()

    def test_with_props_mixin(self):
        self.suggest('''library foo;

class FooProps extends UiProps with FooPropsMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooProps extends UiProps with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin {\n',
            ],
        ))

    def test_with_state_mixin(self):
        self.suggest('''library foo;

class FooState extends UiState with FooStateMixin {
  String foo;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooState extends UiState with \n',
                '    FooStateMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooStateMixin {\n',
            ],
        ))

    def test_with_multiple_mixins(self):
        self.suggest('''library foo;

class FooProps extends UiProps with FooPropsMixin, BarPropsMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooProps extends UiProps with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin, \n',
                '    BarPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $BarPropsMixin {\n',
            ],
        ))

    def test_with_leading_and_trailing_other_mixins(self):
        self.suggest('''library foo;

class FooProps extends UiProps with FooOtherMixin, BarPropsMixin, BazOtherMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooProps extends UiProps with FooOtherMixin, \n',
                '    BarPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $BarPropsMixin, BazOtherMixin {\n',
            ],
        ))

    def test_multiline_class_declaration(self):
        self.suggest('''library foo;

abstract class FooProps
    extends LongSuperClassName
    with FooPropsMixin, OtherMixin, AnotherMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=5,
            new_lines=[
                'abstract class FooProps\n',
                '    extends LongSuperClassName\n',
                '    with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin, OtherMixin, AnotherMixin {\n',
            ],
        ))

    def test_with_on_class_line(self):
        self.suggest('''library foo;

abstract class FooProps extends UiProps with
    FooPropsMixin, OtherMixin, AnotherMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                'abstract class FooProps extends UiProps with\n',
                '    \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin, OtherMixin, AnotherMixin {\n',
            ],
        ))

    def test_with_on_own_line(self):
        self.suggest('''library foo;

abstract class FooProps extends UiProps
    with
        FooPropsMixin,
        BarPropsMixin,
        OtherMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=7,
            new_lines=[
                'abstract class FooProps extends UiProps\n',
                '    with\n',
                '        \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin,\n',
                '        \n',
                '    BarPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $BarPropsMixin,\n',
                '        OtherMixin {\n',
            ],
        ))

    def test_implements_same_line(self):
        self.suggest('''library foo;

abstract class FooProps extends UiProps
    with FooPropsMixin implements BarInterface {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                'abstract class FooProps extends UiProps\n',
                '    with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin implements BarInterface {\n',
            ],
        ))

    def test_implements_next_line(self):
        self.suggest('''library foo;

abstract class FooProps
    extends UiProps
    with PreMixin, FooPropsMixin, PostMixin
    implements BarInterface {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=6,
            new_lines=[
                'abstract class FooProps\n',
                '    extends UiProps\n',
                '    with PreMixin, \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin, PostMixin\n',
                '    implements BarInterface {\n',
            ],
        ))

    def test_implements_multiple(self):
        self.suggest('''library foo;

abstract class FooProps extends UiProps
    with PreMixin, FooPropsMixin, PostMixin implements BarInterface, BazInterface {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                'abstract class FooProps extends UiProps\n',
                '    with PreMixin, \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin, PostMixin implements BarInterface, BazInterface {\n',
            ],
        ))

    def test_private_class(self):
        self.suggest('''library foo;

class _FooProps extends UiProps with FooPropsMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class _FooProps extends UiProps with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin {\n',
            ],
        ))

    def test_private_dollar_class(self):
        self.suggest('''library foo;

class _$FooProps extends UiProps with FooPropsMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class _$FooProps extends UiProps with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin {\n',
            ],
        ))

    def test_private_mixin(self):
        self.suggest('''library foo;

class FooProps extends UiProps with _FooPropsMixin {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooProps extends UiProps with \n',
                '    _FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $_FooPropsMixin {\n',
            ],
        ))

    def test_mixin_with_single_generic(self):
        self.suggest('''library foo;

abstract class FooProps<P> extends UiProps
    with FooPropsMixin<P> {
  String prop;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                'abstract class FooProps<P> extends UiProps\n',
                '    with \n',
                '    FooPropsMixin<P>,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin<P> {\n',
            ],
        ))

    def test_already_added(self):
        self.suggest('''library foo;

class FooProps extends UiProps with
    FooPropsMixin,
    // ignore: mixin_of_non_class, undefined_class
    $FooPropsMixin {
  String prop;
}''')
        self.assert_no_patches_suggested()

    def test_multiple_classes(self):
        self.suggest('''library foo;

class FooProps extends UiProps with FooPropsMixin {}

class BarProps extends UiProps with BarPropsMixin {}
''')
        self.assert_num_patches_suggested(2)

    def test_ignore_match_across_two_classes(self):
        self.suggest('''library foo;

class FooProps extends UiProps with OtherMixin {}

// Blah blah with BarPropsMixin blah blah
void fn() {}''')
        self.assert_no_patches_suggested()

    def test_ignore_comments(self):
        self.suggest('''library foo;

class Foo {
  /// Blah blah with blah blah
  /// 
  /// > Blah blah [FooPropsMixin]
  void bar() {
    
  }
}''')
        self.assert_no_patches_suggested()

    def test_ignores_mixin_in_implements(self):
        self.suggest('''library foo;

class Foo extends UiProps with OtherMixin implements FooPropsMixin {}
''')
        self.assert_no_patches_suggested()

    def test_ignores_mixin_before_with(self):
        self.suggest('''library foo;

class FooPropsMixinView extends UiProps with FooPropsMixin {}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=3,
            new_lines=[
                'class FooPropsMixinView extends UiProps with \n',
                '    FooPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $FooPropsMixin {}\n',
            ],
        ))

    def test_with_in_comment_just_before_valid_usage(self):
        self.suggest('''library foo;

@PropsMixin()
abstract class ButtonPropsMixin {
  /// Blah blah with blah blah.
}

@Props()
class _$ButtonProps extends UiProps
    with ButtonPropsMixin {}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=8,
            end_line_number=10,
            new_lines=[
                'class _$ButtonProps extends UiProps\n',
                '    with \n',
                '    ButtonPropsMixin,\n',
                '    // ignore: mixin_of_non_class, undefined_class\n',
                '    $ButtonPropsMixin {}\n',
            ]
        ))

    def test_with_after_class_body_start(self):
        self.suggest('''library foo;

class _HasPropMatcher extends CustomMatcher {

  _HasPropMatcher(propKey, propValue)
      : this._propKey = propKey,
        super('React instance with props that', 'props/attributes map', containsPair(propKey, propValue));

  static bool _isValidDomPropKey(propKey) => DomPropsMixin.meta.keys.contains(propKey);

  @override
  Map featureValueOf(item) {
    // foo
  }
}''')
        self.assert_no_patches_suggested()

    def test_wsd(self):
        self.suggest('''library foo;

/// A MapView with the typed getters/setters for [FormComponentDisplayPropsMixin].
class FormComponentDisplayPropsMapView extends UiPropsMapView with
    DomPropsMixin,
    FormComponentDisplayPropsMixin,
    FormComponentWrapperPropsMixin {
  /// Create a new instance backed by the specified map.
  FormComponentDisplayPropsMapView(Map map) : super(map);
}''')
        self.assert_num_patches_suggested(1)