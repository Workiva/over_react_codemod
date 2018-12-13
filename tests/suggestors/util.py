import codemod
import unittest


class CodemodPatchTestCase(unittest.TestCase):

    patches = None

    @property
    def suggestor(self):
        self.assertIn
        pass

    def setUp(self):
        super(CodemodPatchTestCase, self).setUp()
        self.patches = None

    def assert_no_patches_suggested(self):
        self.assert_suggest_called()
        num_patches = len(self.patches)
        self.assertEqual(
            num_patches,
            0,
            'No patches expected, but %d patch(es) were suggested' % num_patches)

    def assert_num_patches_suggested(self, num_expected):
        self.assert_suggest_called()
        self.assertEqual(len(self.patches), num_expected, '%d patches expected, but %d suggested.' % (
            num_expected, len(self.patches)))

    def assert_patch_suggested(self, expected_patch):
        self.assert_suggest_called()
        for patch in self.patches:
            if self.are_patches_equal(patch, expected_patch):
                return
        self.fail('''Patch not suggested.

Expected:
    %s
Actual patches:
    %s
''' % (repr(expected_patch), '\n    '.join(map(repr, self.patches))))

    def assert_suggest_called(self):
        if self.patches is None:
            raise Exception(
                'Call self.suggest() before using self.assert_patch_suggested()')

    def are_patches_equal(self, patch1, patch2):
        return (
            patch1.start_line_number == patch2.start_line_number and
            patch1.end_line_number == patch2.end_line_number and
            patch1.new_lines == patch2.new_lines
        )

    def suggest(self, content, path=None):
        self.patches = list(
            self.suggestor(
                ['%s\n' % line for line in content.split('\n')],
                path,
            )
        )
