# Copyright 2018 Workiva Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
