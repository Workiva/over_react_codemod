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

from ..context import component_default_props
from .util import CodemodPatchTestCase

import codemod
import re
import unittest


class TestComponentDefaultPropsSuggestor(CodemodPatchTestCase):

    @property
    def suggestor(self):
        return component_default_props.component_default_props_suggestor

    def test_empty(self):
        self.suggest('')
        self.assert_no_patches_suggested()

    def test_no_match(self):
        self.suggest('''library foo;
void nothingToDoHere() {
    print("...");
}''')
        self.assert_no_patches_suggested()

    def test_one_line(self):
        self.suggest(
            'var defaultProps = new FooComponent().getDefaultProps();')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines=[
                'var defaultProps = Foo().componentDefaultProps;\n',
            ],
        ))

    def test_two_lines(self):
        self.suggest('''
var defaultProps = new FooComponent()
    .getDefaultProps();''')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=3,
            new_lines=[
                'var defaultProps = Foo().componentDefaultProps;\n',
            ],
        ))

    def test_multiple_on_same_line(self):
        self.suggest(
            'var p = [new FooComponent().getDefaultProps(), new BarComponent().getDefaultProps()];')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines=[
                'var p = [Foo().componentDefaultProps, Bar().componentDefaultProps];\n',
            ],
        ))

    def test_special_chars(self):
        self.suggest(
            'var defaultProps = new Foo_BarComponent().getDefaultProps();')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=0,
            new_lines=[
                'var defaultProps = Foo_Bar().componentDefaultProps;\n',
            ],
        ))

    def multiple_ocurrences(self):
        self.suggest('''library foo;
class FooComponent {
  @override
  Map getDefaultProps() => newProps()
    ..addAll(new BazComponent().getDefaultProps())
    ..addAll(new BarComponent()
        .getDefaultProps())
    ..addAll(new OtherComponent().getDefaultProps());
}''')
        self.assert_num_patches_suggested(2)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=4,
            new_lines=[
                'Baz().componentDefaultProps',
            ],
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=5,
            end_line_number=7,
            new_lines=[
                'Bar().componentDefaultProps',
            ],
        ))
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=7,
            new_lines=[
                'Other().componentDefaultProps',
            ],
        ))
