from ..context import generated_parts
from .util import CodemodPatchTestCase

import codemod
import mock
import re
import unittest


class CollectLibrariesSuggestor(CodemodPatchTestCase):

    def setUp(self):
        super(CollectLibrariesSuggestor, self).setUp()
        generated_parts.libraries_that_need_generated_part_by_name = set([])
        generated_parts.libraries_that_need_generated_part_by_path = set([])

    @property
    def suggestor(self):
        return generated_parts.collect_libraries_suggestor

    @mock.patch('tests.context.util.needs_over_react_generated_part', return_value=False)
    def test_generation_not_needed(self, _):
        self.suggest('')
        self.assert_no_patches_suggested()

    @mock.patch('tests.context.util.needs_over_react_generated_part', return_value=True)
    @mock.patch('tests.context.util.parse_part_of_name', return_value=None)
    @mock.patch('tests.context.util.parse_part_of_uri', return_value='package:foo/foo/bar.dart')
    def test_part_of_uri_package(self, _1, _2, _3):
        self.suggest('')
        self.assert_no_patches_suggested()
        self.assertIn('./lib/foo/bar.dart',
                      generated_parts.libraries_that_need_generated_part_by_path)

    @mock.patch('tests.context.util.needs_over_react_generated_part', return_value=True)
    @mock.patch('tests.context.util.parse_part_of_name', return_value=None)
    @mock.patch('tests.context.util.parse_part_of_uri', return_value='../foo/bar.dart')
    def test_part_of_uri_path(self, _1, _2, _3):
        self.suggest('', 'lib/bar/baz.dart')
        self.assert_no_patches_suggested()
        self.assertIn('lib/foo/bar.dart',
                      generated_parts.libraries_that_need_generated_part_by_path)

    @mock.patch('tests.context.util.needs_over_react_generated_part', return_value=True)
    @mock.patch('tests.context.util.parse_part_of_name', return_value='foo.bar.baz')
    @mock.patch('tests.context.util.parse_part_of_uri', return_value=None)
    def test_part_of_name(self, _1, _2, _3):
        self.suggest('')
        self.assert_no_patches_suggested()
        self.assertIn('foo.bar.baz',
                      generated_parts.libraries_that_need_generated_part_by_name)

    @mock.patch('tests.context.util.needs_over_react_generated_part', return_value=True)
    def test_library(self, _):
        path = 'path/to/file.dart'
        self.suggest('', path)
        self.assert_no_patches_suggested()
        self.assertIn(
            path, generated_parts.libraries_that_need_generated_part_by_path)


class TestGeneratedPartsSuggestor(CodemodPatchTestCase):

    def setUp(self):
        super(TestGeneratedPartsSuggestor, self).setUp()
        generated_parts.libraries_that_need_generated_part_by_name = set([])
        generated_parts.libraries_that_need_generated_part_by_path = set([])

    @property
    def suggestor(self):
        return generated_parts.generated_parts_suggestor

    def test_generated_part_not_needed(self):
        self.suggest('')
        self.assert_no_patches_suggested()

    def test_referenced_by_name(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('library foo;', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=1,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_referenced_by_path(self):
        generated_parts.libraries_that_need_generated_part_by_path.add(
            'path/to/foo.dart')
        self.suggest('library foo;', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=1,
            end_line_number=1,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_after_imports(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('''library foo;

import 'dart:async';
import 'package:bar/bar.dart';
import '../baz.dart';

void someCode() {}
''', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=5,
            end_line_number=5,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_after_exports(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('''library foo;

export 'dart:async';
export 'package:bar/bar.dart';
export '../baz.dart';

void someCode() {}
''', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=5,
            end_line_number=5,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_after_parts(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('''library foo;

part 'bar.dart';
part '../baz.dart';

void someCode() {}
''', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=4,
            end_line_number=4,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_after_directive_with_line_wrap(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('''library foo;

import 'package:bar/bar.dart'
    show Bar;

void someCode() {}
''', 'path/to/foo.dart')
        self.assert_num_patches_suggested(1)
        self.assert_patch_suggested(codemod.Patch(
            start_line_number=4,
            end_line_number=4,
            new_lines=[
                '\n',
                '// ignore: uri_does_not_exist, uri_has_not_been_generated\n',
                "part 'foo.over_react.g.dart';\n",
            ],
        ))

    def test_already_added(self):
        generated_parts.libraries_that_need_generated_part_by_name.add('foo')
        self.suggest('''library foo;

part 'foo.over_react.g.dart';

void someCode() {}
''', 'path/to/foo.dart')
        self.assert_no_patches_suggested()
