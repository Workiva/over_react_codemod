from ..context import factories
from .util import CodemodPatchTestCase

import codemod
import re
import unittest


class TestDollarPropsSuggestor(CodemodPatchTestCase):

    @property
    def suggestor(self):
        return factories.factories_suggestor

    def test_empty(self):
        self.suggest('')
        self.assert_no_patches_suggested()

    def test_no_matches(self):
        self.suggest('''library foo;
void nothingToDoHere() {
    print("...");
}''')
        self.assert_no_patches_suggested()

    def test_basic(self):
        self.suggest('''library foo;

@Factory()
UiFactory<FooProps> Foo;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory<FooProps> Foo = $Foo;\n',
            ],
        ))

    def test_no_generic(self):
        self.suggest('''library foo;

@Factory()
UiFactory Foo;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory Foo = $Foo;\n',
            ],
        ))

    def test_multiple_generics(self):
        self.suggest('''library foo;

@Factory()
UiFactory<FooProps<Bar>> Foo;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory<FooProps<Bar>> Foo = $Foo;\n',
            ],
        ))

    def test_special_chars(self):
        self.suggest('''library foo;

@Factory()
UiFactory<Foo_Props<$Bar>> Foo_Bar;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory<Foo_Props<$Bar>> Foo_Bar = $Foo_Bar;\n',
            ],
        ))

    def test_private(self):
        self.suggest('''library foo;

@Factory()
UiFactory<_PrivateFooProps> _PrivateFoo;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory<_PrivateFooProps> _PrivateFoo = _$PrivateFoo;\n',
            ],
        ))

    def test_commented_out(self):
        self.suggest('''library foo;

// @Factory()
// UiFactory<FooProps> Foo;''')

        self.assert_no_patches_suggested()

    def test_extra_annotation(self):
        self.suggest('''library foo;

@Factory()
@Deprecated('3.0.0')
UiFactory<FooProps> Foo;''')

        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=4,
            new_lines=[
                '// ignore: undefined_identifier\n',
                'UiFactory<FooProps> Foo = $Foo;\n',
            ],
        ))

    def test_already_initialized(self):
        self.suggest('''library foo;

@Factory()
UiFactory<FooProps> Foo = $Foo;''')
        self.assert_no_patches_suggested()
