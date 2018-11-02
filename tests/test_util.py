from .context import regexes
from .context import util

import os

import mock
import unittest


class TestBuildGeneratedPartFilename(unittest.TestCase):

    def test_file(self):
        result = util.build_generated_part_filename('test_file.dart')
        self.assertEqual(result, 'test_file.overReact.g.dart')

    def test_no_parent_dir(self):
        result = util.build_generated_part_filename('./test_file.dart')
        self.assertEqual(result, 'test_file.overReact.g.dart')

    def test_multiple_parent_dirs(self):
        result = util.build_generated_part_filename('./foo/bar/test_file.dart')
        self.assertEqual(result, 'test_file.overReact.g.dart')


class TestBuildLibraryNameFromPath(unittest.TestCase):

    @mock.patch('os.path.basename')
    def test_lib(self, mock_basename):
        mock_basename.return_value = 'bar-baz'
        result = util.build_library_name_from_path('./lib/src/foo.dart')
        self.assertEqual(result, 'bar_baz.src.foo')
        mock_basename.assert_called_once_with(os.path.abspath(os.path.curdir))

    @mock.patch('os.path.basename')
    def test_non_lib(self, mock_basename):
        mock_basename.return_value = 'bar-baz'
        result = util.build_library_name_from_path('./example/foo.dart')
        self.assertEqual(result, 'bar_baz.example.foo')
        mock_basename.assert_called_once_with(os.path.abspath(os.path.curdir))


class TestConvertPartOfURIToRelpath(unittest.TestCase):

    def test_package_uri(self):
        result = util.convert_part_of_uri_to_relpath('package:foo/src/bar.dart')
        self.assertEqual(result, './lib/src/bar.dart')

    def test_package_uri_with_redundancies(self):
        result = util.convert_part_of_uri_to_relpath('package:foo/src/../src/bar.dart')
        self.assertEqual(result, './lib/src/bar.dart')


class TestFindPatches(unittest.TestCase):

    def test_no_lines(self):
        result = list(util.find_patches(regexes.DOLLAR_PROPS_REGEX, [], mock.Mock()))
        self.assertListEqual(result, [])

    def test_no_usages(self):
        result = list(util.find_patches(regexes.DOLLAR_PROPS_REGEX, [
            'library foo.bar;\n',
            '// comment\n',
            'void foo() {}\n',
        ], mock.Mock()))
        self.assertListEqual(result, [])

    def test_one_usage(self):
        updater = mock.Mock()
        updater.return_value = ['test']
        result = list(util.find_patches(regexes.DOLLAR_PROPS_REGEX, [
            'library foo.bar;\n',
            'var p = new $Props(FooProps);\n',
            'void foo() {}\n',
        ], updater))
        self.assertListEqual(result, [
            (
                1,
                2,
                ['test'],
            ),
        ])

    def test_multiple_usages(self):
        updater = mock.Mock()
        updater.return_value = ['test']
        result_iter = util.find_patches(regexes.DOLLAR_PROPS_REGEX, [
            'library foo.bar;\n',
            'var p = new $Props(FooProps);\n',
            'var q = new $Props(\n',
            '  FooProps\n',
            ');\n',
            'void foo() {}\n',
        ], updater)
        first_patch = result_iter.next()
        self.assertEqual(first_patch, (2, 5, ['test']))
        self.assertEqual(updater.call_count, 1)
        updater.assert_called_with([
            'var q = new $Props(\n',
            '  FooProps\n',
            ');\n',
        ])

        second_patch = result_iter.next()
        self.assertEqual(second_patch, (1, 2, ['test']))
        self.assertEqual(updater.call_count, 2)
        updater.assert_called_with([
            'var p = new $Props(FooProps);\n',
        ])

    def test_multiple_usages_on_same_line(self):
        updater = mock.Mock()
        updater.return_value = ['test']
        result = list(util.find_patches(regexes.DOLLAR_PROPS_REGEX, [
            'library foo.bar;\n',
            'var metas = [new $Props(FooProps), const $Props(BarProps)];\n',
            'void foo() {}\n',
        ], updater))
        self.assertListEqual(result, [
            (1, 2, ['test']),
        ])
        updater.assert_called_once_with([
            'var metas = [new $Props(FooProps), const $Props(BarProps)];\n',
        ])


class TestGetLastDirectiveLineNumber(unittest.TestCase):

    def test_no_lines(self):
        result = util.get_last_directive_line_number([])
        self.assertEqual(result, -1)

    def test_no_directives(self):
        result = util.get_last_directive_line_number([
            'void foo() {}\n',
            'class Bar {}\n',
        ])
        self.assertEqual(result, -1)

    def test_directives(self):
        result = util.get_last_directive_line_number([
            'library foo.bar;\n',
            '\n',
            'import "foo/bar.dart";\n',
            '\n',
            'part "foo/baz.dart";\n',
            '\n',
            'function fooBar() {}\n',
        ])
        self.assertEqual(result, 4)


class TestGetLineNumberToInsertParts(unittest.TestCase):

    @mock.patch('tests.context.util.get_last_directive_line_number')
    def test_no_directives(self, mock_get_last_directive_line_number):
        mock_get_last_directive_line_number.return_value = -1
        result = util.get_line_number_to_insert_parts([
            '1\n',
            '2\n',
            '3\n',
        ])
        self.assertEqual(result, 3)

    @mock.patch('tests.context.util.get_last_directive_line_number')
    def test_directives(self, mock_get_last_directive_line_number):
        mock_get_last_directive_line_number.return_value = 1
        result = util.get_line_number_to_insert_parts([
            '1\n',
            '2\n',
            '3\n',
        ])
        self.assertEqual(result, 2)


class TestIsDartFile(unittest.TestCase):

    def test_dart_file(self):
        self.assertTrue(util.is_dart_file('./foo/bar.dart'))

    def test_not_dart_file(self):
        self.assertFalse(util.is_dart_file('./foo/bar.txt'))


class TestNeedsFactoryUpdate(unittest.TestCase):

    def test_needs_update(self):
        self.assertTrue(util.needs_factory_update('UiFactory Foo;'))

    def test_already_updated(self):
        self.assertFalse(util.needs_factory_update('UiFactory Foo = $Foo;'))


class TestNeedsOverReactGeneratedPart(unittest.TestCase):

    def test_needs_generation(self):
        result = util.needs_over_react_generated_part([
            'library foo;\n',
            '@Factory()\n',
            'UiFactory Foo;\n',
        ])
        self.assertTrue(result)

    def test_no_generation_needed(self):
        result = util.needs_over_react_generated_part([
            'library foo;\n',
            '\n',
            'void foo() {}\n',
        ])
        self.assertFalse(result)


class TestParseFactoryName(unittest.TestCase):

    def test_no_match(self):
        result = util.parse_factory_name('UiFactory')
        self.assertIsNone(result)

    def test_not_at_beginning_of_line(self):
        result = util.parse_factory_name('// UiFactory<FooProps> Foo;')
        self.assertIsNone(result)

    def test_no_generic(self):
        result = util.parse_factory_name('UiFactory FooBar;')
        self.assertEqual(result, 'FooBar')

    def test_with_generic(self):
        result = util.parse_factory_name('UiFactory<FooBarProps> FooBar;')
        self.assertEqual(result, 'FooBar')

    def test_already_initialized(self):
        result = util.parse_factory_name('UiFactory<FooBarProps> FooBar = $FooBar;')
        self.assertIsNone(result)


class TestParseLibraryName(unittest.TestCase):

    def test_no_match(self):
        result = util.parse_library_name([
            '// comment\n',
            'void foo() {}\n',
        ])
        self.assertIsNone(result)

    def test_match(self):
        result = util.parse_library_name([
            '// comment\n',
            'library foo.bar;\n',
            'void foo() {}\n',
        ])
        self.assertEqual(result, 'foo.bar')


class TestParsePartOfName(unittest.TestCase):

    def test_no_match(self):
        result = util.parse_part_of_name([
            '// comment\n',
            'void foo() {}\n',
        ])
        self.assertIsNone(result)

    def test_match(self):
        result = util.parse_part_of_name([
            '// comment\n',
            'part of foo.bar;\n',
            'void foo() {}\n',
        ])
        self.assertEqual(result, 'foo.bar')


class TestParsePartOfURI(unittest.TestCase):

    def test_no_match(self):
        result = util.parse_part_of_uri([
            '// comment\n',
            'void foo() {}\n',
        ])
        self.assertIsNone(result)

    def test_match(self):
        result = util.parse_part_of_uri([
            '// comment\n',
            'part of "foo/bar.dart";\n',
            'void foo() {}\n',
        ])
        self.assertEqual(result, 'foo/bar.dart')


class TestParsePartPaths(unittest.TestCase):

    def test_no_parts(self):
        results = list(util.parse_part_paths([
            'library foo.bar;\n',
            '// comment\n',
            'void foo() {}\n',
        ]))
        self.assertListEqual(results, [])

    def test_parts(self):
        results = list(util.parse_part_paths([
            'library foo.bar;\n',
            'part "foo/bar.dart";\n',
            'part "foo/baz.dart";\n',
            'void foo() {}\n',
        ]))
        self.assertListEqual(results, [
            'foo/bar.dart',
            'foo/baz.dart',
        ])


class TestSearchPatternOverOneOrTwoLines(unittest.TestCase):

    def test_no_match(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'nomatch',
            [
                'one\n',
                'two\n',
                'test\n',
            ],
        )
        self.assertIsNone(result)

    def test_match_first_line(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'^test$',
            [
                'test\n',
                'two\n',
                'three\n',
            ],
        )
        self.assertEqual(result.group(0), 'test')

    def test_match_last_line(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'^test$',
            [
                'one\n',
                'two\n',
                'test\n',
            ],
        )
        self.assertEqual(result.group(0), 'test')

    def test_first_two_lines(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'^test1\s*test2$',
            [
                'test1\n',
                'test2\n',
                'three\n',
            ],
        )
        self.assertEqual(result.group(0), 'test1\ntest2')

    def test_last_two_lines(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'^test1\s*test2$',
            [
                'one\n',
                'test1\n',
                'test2\n',
            ],
        )
        self.assertEqual(result.group(0), 'test1\ntest2')

    def test_two_lines(self):
        result = util.search_pattern_over_one_or_two_lines(
            r'^test1\s*test2$',
            [
                'one\n',
                'test1\n',
                'test2\n',
                'four\n',
            ],
        )
        self.assertEqual(result.group(0), 'test1\ntest2')
