from .context import updaters

import unittest


class TestUpdateDollarProps(unittest.TestCase):

    def test_one_line(self):
        result = updaters.update_dollar_props(
            'var p = const $Props(FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta;\n',
        ])

    def test_two_lines(self):
        result = updaters.update_dollar_props(
            'var p = const $Props(\n'
            '  FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta;\n',
        ])

    def test_three_lines(self):
        result = updaters.update_dollar_props(
            'var p = const $Props(\n'
            '  FooProps,\n'
            ');\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta;\n',
        ])

    def test_with_over_react_import_prefix(self):
        result = updaters.update_dollar_props(
            'var p = const or_prefix.$Props(FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta;\n',
        ])

    def test_with_props_arg_import_prefix(self):
        result = updaters.update_dollar_props(
            'var p = const $Props(import_prefix.FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = import_prefix.FooProps.meta;\n',
        ])


class TestUpdateDollarPropKeys(unittest.TestCase):

    def test_one_line(self):
        result = updaters.update_dollar_prop_keys(
            'var p = const $PropKeys(FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta.keys;\n',
        ])

    def test_two_lines(self):
        result = updaters.update_dollar_prop_keys(
            'var p = const $PropKeys(\n'
            '  FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta.keys;\n',
        ])

    def test_three_lines(self):
        result = updaters.update_dollar_prop_keys(
            'var p = const $PropKeys(\n'
            '  FooProps,\n'
            ');\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta.keys;\n',
        ])

    def test_with_over_react_import_prefix(self):
        result = updaters.update_dollar_prop_keys(
            'var p = const or_prefix.$PropKeys(FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = FooProps.meta.keys;\n',
        ])

    def test_with_props_arg_import_prefix(self):
        result = updaters.update_dollar_prop_keys(
            'var p = const $PropKeys(import_prefix.FooProps);\n'
        )
        self.assertListEqual(result, [
            'var p = import_prefix.FooProps.meta.keys;\n',
        ])


class TestUpdateFactory(unittest.TestCase):

    def test_factory(self):
        result = updaters.update_factory(
            'UiFactory<FooProps> Foo;\n'
        )
        self.assertListEqual(result, [
            '// ignore: undefined_identifier\n',
            'UiFactory<FooProps> Foo = $Foo;\n',
        ])

    def test_factory_with_trailing_comment(self):
        result = updaters.update_factory(
            'UiFactory Foo; // a comment\n'
        )
        self.assertListEqual(result, [
            '// ignore: undefined_identifier\n',
            'UiFactory Foo = $Foo; // a comment\n',
        ])

    def test_multiline(self):
        result = updaters.update_factory(
            'UiFactory<VeryLongProps>\n'
            '  Foo;\n'
        )
        self.assertListEqual(result, [
            '// ignore: undefined_identifier\n',
            'UiFactory<VeryLongProps>\n',
            '  Foo = $Foo;\n',
        ])

