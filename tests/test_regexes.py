from .context import regexes

import re
import unittest


class RegexTestCase(unittest.TestCase):

    @property
    def regex(self):
        raise NotImplementedError

    def assert_has_match(self, string, msg=None, expected_groups=None):
        match = re.search(self.regex, string)
        self.assertIsNotNone(match, msg=msg)
        if expected_groups:
            for group, expected_value in expected_groups.iteritems():
                self.assertEqual(match.group(group), expected_value)

    def assert_has_no_match(self, string):
        self.assertIsNone(re.search(self.regex, string))


class TestDartExtensionRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.DART_EXTENSION_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('foo.txt')
        self.assert_has_no_match('../foo/bar/baz')

    def test_not_at_end(self):
        self.assert_has_no_match('foo.dart.txt')

    def test_file(self):
        self.assert_has_match('foo.dart')

    def test_multiple_extensions(self):
        self.assert_has_match('foo.txt.dart')

    def test_path(self):
        self.assert_has_match('foo/bar.dart')
        self.assert_has_match('../foo/bar.dart')


class TestDirectiveRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.DIRECTIVE_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('/// Doc comment')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('// library foo.bar;')

    def test_library(self):
        self.assert_has_match('library foo;')
        self.assert_has_match('library foo_bar;', msg='underscore')
        self.assert_has_match('library foo.bar.baz;', msg='dot-delimited')
        self.assert_has_match('library\n    really_long.library.name;', msg='multi-line')

    def test_import(self):
        self.assert_has_match('''import "package:foo/bar.dart";''', msg='package (double quote)')
        self.assert_has_match('''import 'package:foo/bar.dart';''', msg='package (single quote)')

        self.assert_has_match('''import "../foo/bar.dart";''', msg='relative (double quote)')
        self.assert_has_match('''import '../foo/bar.dart';''', msg='relative (single quote)')

        self.assert_has_match('''import\n    "package:foo/long/import.dart";''', msg='multi-line (double quote)')
        self.assert_has_match('''import\n    'package:foo/long/import.dart';''', msg='multi-line (single quote)')

    def test_export(self):
        self.assert_has_match('''export "package:foo/bar.dart";''', msg='package (double quote)')
        self.assert_has_match('''export 'package:foo/bar.dart';''', msg='package (single quote)')

        self.assert_has_match('''export "../foo/bar.dart";''', msg='relative (double quote)')
        self.assert_has_match('''export '../foo/bar.dart';''', msg='relative (single quote)')

        self.assert_has_match('''export\n    "package:foo/long/export.dart";''', msg='multi-line (double quote)')
        self.assert_has_match('''export\n    'package:foo/long/export.dart';''', msg='multi-line (single quote)')

    def test_part(self):
        self.assert_has_match('''part "package:foo/bar.dart";''', msg='package (double quote)')
        self.assert_has_match('''part 'package:foo/bar.dart';''', msg='package (single quote)')

        self.assert_has_match('''part "../foo/bar.dart";''', msg='relative (double quote)')
        self.assert_has_match('''part '../foo/bar.dart';''', msg='relative (single quote)')

        self.assert_has_match('''part\n    "package:foo/long/part.dart";''', msg='multi-line (double quote)')
        self.assert_has_match('''part\n    'package:foo/long/part.dart';''', msg='multi-line (single quote)')


class TestFactoryRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.FACTORY_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('library foo.bar;')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('/// Doc comment')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('// UiFactory<FooBarProps> FooBar;')

    def test_already_initialized(self):
        self.assert_has_no_match('UiFactory<FooBarProps> FooBar = $FooBar;')
        self.assert_has_no_match('UiFactory<FooBarProps> FooBar\n    = $FooBar;')

    def test_no_generic(self):
        self.assert_has_match(
            'UiFactory FooBar;',
            expected_groups={1: 'FooBar'},
        )

    def test_with_generic(self):
        self.assert_has_match(
            'UiFactory<FooBarProps> FooBar;',
            expected_groups={1: 'FooBar'},
        )

    def test_with_multiple_generics(self):
        self.assert_has_match(
            'UiFactory<FooProps<Bar>> FooBar;',
            expected_groups={1: 'FooBar'},
        )

    def test_with_underscore(self):
        self.assert_has_match(
            'UiFactory<Foo_BarProps> Foo_Bar;',
            expected_groups={1: 'Foo_Bar'},
        )


class TestLibraryNameRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.LIBRARY_NAME_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('// library foo.bar;')

    def test_no_whitespace_in_library_name(self):
        self.assert_has_no_match('library foo bar;')

    def test_library(self):
        self.assert_has_match(
            'library foo_barBaz;',
            expected_groups={1: 'foo_barBaz'},
        )

    def test_library_dot_delimited(self):
        self.assert_has_match(
            'library foo.bar.BazBuzz;',
            expected_groups={1: 'foo.bar.BazBuzz'},
        )

    def test_library_multiline(self):
        self.assert_has_match(
            'library\n    foo.bar;',
            expected_groups={1: 'foo.bar'},
        )


class TestNeedsPartRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.NEEDS_GENERATED_PART_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('library foo.bar;')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('// @Factory()')
        self.assert_has_no_match('// @Props()')

    def test_factory_annotation(self):
        self.assert_has_match('@Factory()')

    def test_props_annotations(self):
        self.assert_has_match('@Props()')
        self.assert_has_match('@PropsMixin()')
        self.assert_has_match('@AbstractProps()')

    def test_state_annotations(self):
        self.assert_has_match('@State()')
        self.assert_has_match('@StateMixin()')
        self.assert_has_match('@AbstractState()')

    def test_component_annotation(self):
        self.assert_has_match('@Component()')


class TestPackageURIPrefixRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.PACKAGE_URI_PREFIX_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('https://foo')
        self.assert_has_no_match('lib/foo')
        self.assert_has_no_match('../lib/foo')

    def test_not_at_beginning(self):
        self.assert_has_no_match('./package:foo/bar.dart')

    def test_package_uri(self):
        self.assert_has_match(
            'package:foo/bar.dart',
            expected_groups={0: 'package:foo/'},
        )
        self.assert_has_match(
            'package:foo/src/bar.dart',
            expected_groups={0: 'package:foo/'},
        )


class TestPartOfNameRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.PART_OF_NAME_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('library foo.bar;')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('// part of foo.bar;')

    def test_part_but_not_part_of(self):
        self.assert_has_no_match('''part "../foo/bar.dart";''')
        self.assert_has_no_match('''part '../foo/bar.dart';''')

    def test_part_of_library_name(self):
        self.assert_has_match(
            'part of foo;',
            expected_groups={1: 'foo'},
        )
        self.assert_has_match(
            'part of foo_bar;',
            msg='underscore',
            expected_groups={1: 'foo_bar'},
        )
        self.assert_has_match(
            'part of foo.bar.baz;',
            msg='dot-delimited',
            expected_groups={1: 'foo.bar.baz'},
        )
        self.assert_has_match(
            'part of\n    really.long.library.name;',
            msg='multi-line',
            expected_groups={1: 'really.long.library.name'},
        )


class TestPartOfURIRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.PART_OF_URI_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('library foo.bar;')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning_of_line(self):
        self.assert_has_no_match('''// part of "./foo/bar.dart";''')
        self.assert_has_no_match('''// part of './foo/bar.dart';''')

    def test_part_but_not_part_of(self):
        self.assert_has_no_match('''part "../foo/bar.dart";''')
        self.assert_has_no_match('''part '../foo/bar.dart';''')

    def test_part_of_library_path(self):
        self.assert_has_match(
            '''part of "../foo/bar.dart";''',
            msg='relative (double quotes)',
            expected_groups={1: '../foo/bar.dart'},
        )
        self.assert_has_match(
            '''part of '../foo/bar.dart';''',
            msg='relative (single quotes)',
            expected_groups={1: '../foo/bar.dart'},
        )

        self.assert_has_match(
            '''part of "package:foo/bar.dart";''',
            msg='package (double quotes)',
            expected_groups={1: 'package:foo/bar.dart'},
        )
        self.assert_has_match(
            '''part of 'package:foo/bar.dart';''',
            msg='package (single quotes)',
            expected_groups={1: 'package:foo/bar.dart'},
        )

        self.assert_has_match(
            '''part of\n    "../../really/long/path.dart";''',
            msg='multi-line (double quotes)',
            expected_groups={1: '../../really/long/path.dart'},
        )
        self.assert_has_match(
            '''part of\n    '../../really/long/path.dart';''',
            msg='multi-line (single quotes)',
            expected_groups={1: '../../really/long/path.dart'},
        )


class TestPartRegex(RegexTestCase):

    @property
    def regex(self):
        return regexes.PART_REGEX

    def test_sanity_checks(self):
        self.assert_has_no_match('')
        self.assert_has_no_match(' ')
        self.assert_has_no_match(' \n ')
        self.assert_has_no_match('library foo.bar;')
        self.assert_has_no_match('import "./foo/bar.dart";')
        self.assert_has_no_match('class FooBar {}')
        self.assert_has_no_match('function fooBar(int test) {}')

    def test_not_at_beginning(self):
        self.assert_has_no_match('''// part "foo.dart";''')
        self.assert_has_no_match('''// part 'foo.dart';''')

    def test_part(self):
        self.assert_has_match(
            '''part "foo/bar.dart";''',
            msg='relative (double quotes)',
            expected_groups={1: 'foo/bar.dart'},
        )
        self.assert_has_match(
            '''part 'foo/bar.dart';''',
            msg='relative (single quotes)',
            expected_groups={1: 'foo/bar.dart'},
        )
