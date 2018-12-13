from ..context import dollar_props
from .util import CodemodPatchTestCase

import codemod
import re
import unittest


class TestDollarPropsSuggestor(CodemodPatchTestCase):

    @property
    def suggestor(self):
        return dollar_props.dollar_props_suggestor

    def test_empty(self):
        self.suggest('')
        self.assert_no_patches_suggested()

    def test_no_matches(self):
        self.suggest('''library foo;
void nothingToDoHere() {
    print("...");
}''')
        self.assert_no_patches_suggested()

    def test_const_one_line(self):
        self.suggest('var p = const $Props(FooProps);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var p = FooProps.meta;\n',
        ))

        self.suggest('var k = const $PropKeys(FooProps);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var k = FooProps.meta.keys;\n',
        ))

    def test_new_one_line(self):
        self.suggest('var p = new $Props(FooProps);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var p = FooProps.meta;\n',
        ))

        self.suggest('var k = new $PropKeys(FooProps);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var k = FooProps.meta.keys;\n',
        ))

    def test_import_prefix_and_special_chars(self):
        self.suggest('var p = new over_react.$Props(consumer.$My_Props);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var p = consumer.$My_Props.meta;\n',
        ))

        self.suggest('var k = new over_react.$PropKeys(consumer.$My_Props);')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var k = consumer.$My_Props.meta.keys;\n',
        ))

    def test_two_lines(self):
        self.suggest('''
var p = new $Props(
    FooProps);''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=3,
            new_lines='var p = FooProps.meta;\n',
        ))

        self.suggest('''
var k = new $PropKeys(
    FooProps);''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=3,
            new_lines='var k = FooProps.meta.keys;\n',
        ))

    def test_three_lines(self):
        self.suggest('''
var p = new $Props(
    FooProps,
);''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=4,
            new_lines='var p = FooProps.meta;\n',
        ))

        self.suggest('''
var k = new $PropKeys(
    FooProps,
);''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=4,
            new_lines='var k = FooProps.meta.keys;\n',
        ))

    def test_multiple_on_one_line(self):
        self.suggest('var p = [new $Props(Foo), new $Props(Bar)];')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var p = [Foo.meta, Bar.meta];\n',
        ))

        self.suggest('var p = [new $PropKeys(Foo), new $PropKeys(Bar)];')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines='var p = [Foo.meta.keys, Bar.meta.keys];\n',
        ))

    def test_multiple_occurrences(self):
        self.suggest('''library foo;
var propsMetas = [
  new $Props(FooProps),
  new $Props(BarProps),
  new $Props(BazProps),
];
var propsKeys = [
  new $PropKeys(FooProps),
  new $PropKeys(BarProps),
  new $PropKeys(BazProps),
];''')

        self.assert_num_patches_suggested(6)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=2,
            new_lines='  FooProps.meta,\n'
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=3,
            new_lines='  BarProps.meta,\n'
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=4,
            new_lines='  BazProps.meta,\n'
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=7,
            new_lines='  FooProps.meta.keys,\n'
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=8,
            new_lines='  BarProps.meta.keys,\n'
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=9,
            new_lines='  BazProps.meta.keys,\n'
        ))
