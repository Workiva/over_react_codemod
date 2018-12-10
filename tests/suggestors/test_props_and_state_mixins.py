from ..context import props_and_state_mixins
from .util import CodemodPatchTestCase

import codemod
import mock
import re
import unittest


class TestPropsAndStateMixinsMetaSuggestor(CodemodPatchTestCase):

    @property
    def suggestor(self):
        return props_and_state_mixins.props_and_state_mixins_meta_suggestor

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

    def test_props_mixin(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_abstract_props_mixin(self):
        self.suggest('''library foo;

@PropsMixin()
abstract class FooPropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'abstract class FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_state_mixin(self):
        self.suggest('''library foo;

@StateMixin()
class FooStateMixin implements UiState {
  String state1;

  bool state2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@StateMixin()\n',
                'class FooStateMixin implements UiState {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const StateMeta meta = $metaForFooStateMixin;\n',
                '\n',
            ],
        ))

    def test_abstract_state_mixin(self):
        self.suggest('''library foo;

@StateMixin()
abstract class FooStateMixin implements UiState {
  String state1;

  bool state2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@StateMixin()\n',
                'abstract class FooStateMixin implements UiState {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const StateMeta meta = $metaForFooStateMixin;\n',
                '\n',
            ],
        ))

    def test_annotation_with_arg(self):
        self.suggest('''library foo;

@PropsMixin(keyNamespace: 'test')
class FooPropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                "@PropsMixin(keyNamespace: 'test')\n",
                'class FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_multiple_annotations(self):
        self.suggest('''library foo;

@PropsMixin()
@Deprecated('3.0.0')
class FooPropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=5,
            new_lines=[
                '@PropsMixin()\n',
                "@Deprecated('3.0.0')\n",
                'class FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_generics(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin<T extends Iterable, Foo<U>> implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class FooPropsMixin<T extends Iterable, Foo<U>> implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_empty_class(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin implements UiProps {}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '}\n',
            ],
        ))

    def test_special_chars(self):
        self.suggest('''library foo;

@PropsMixin()
class $Foo_PropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class $Foo_PropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaFor$Foo_PropsMixin;\n',
                '\n',
            ],
        ))

    def test_private(self):
        self.suggest('''library foo;

@PropsMixin()
class _FooPropsMixin implements UiProps {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class _FooPropsMixin implements UiProps {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaFor_FooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_no_implements(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=4,
            new_lines=[
                '@PropsMixin()\n',
                'class FooPropsMixin {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_multiple_line_class_declaration(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin implements
    UiProps,
    BarPropsInterface,
    BazPropsInterface {
  String prop1;

  bool prop2;
}''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            end_line_number=7,
            new_lines=[
                '@PropsMixin()\n',
                'class FooPropsMixin implements\n',
                '    UiProps,\n',
                '    BarPropsInterface,\n',
                '    BazPropsInterface {\n',
                '  // To ensure the codemod regression checking works properly, please keep this\n',
                '  // field at the top of the class!\n',
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  static const PropsMeta meta = $metaForFooPropsMixin;\n',
                '\n',
            ],
        ))

    def test_already_added(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin implements UiProps {
  // To ensure the codemod regression checking works properly, please keep this
  // field at the top of the class!
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForFooPropsMixin;

  String prop1;

  bool prop2;
}

class FooProps extends _$FooProps with _$FooPropsAccessorsMixin {}''')
        self.assert_no_patches_suggested()

    def test_already_added_extra_whitespace(self):
        self.suggest('''library foo;

@PropsMixin()
class FooPropsMixin implements UiProps {

  // To ensure the codemod regression checking works properly, please keep this
  // field at the top of the class!
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForFooPropsMixin;

  String prop1;

  bool prop2;
}

class FooProps extends _$FooProps with _$FooPropsAccessorsMixin {}''')
        self.assert_no_patches_suggested()
