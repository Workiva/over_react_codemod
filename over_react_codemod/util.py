from __future__ import print_function
from collections import OrderedDict
import os
import re
import sys

from . import regexes


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def build_generated_part_filename(path):
    """
    For a given file path, return the filename for the accompanying generated part.

    >>> build_generated_part_filename('./foo/bar/baz.dart')
    'baz.over_react.g.dart'
    """
    return re.sub(
        regexes.DART_EXTENSION_REGEX,
        '.over_react.g.dart',
        os.path.basename(path),
    )


def build_library_name_from_path(path):
    project_dirname = os.path.basename(os.path.abspath(os.path.curdir))
    project_name = os.path.split(project_dirname)[-1].replace('-', '_')
    path = re.sub(regexes.DART_EXTENSION_REGEX, '', path)
    path = path.replace('./', '')
    return project_name + '.' + path.replace('/', '.').replace('lib.', '')


def convert_part_of_uri_to_relpath(uri):
    return os.path.join(
        '.',
        os.path.normpath(
            re.sub(regexes.PACKAGE_URI_PREFIX_REGEX, './lib/', uri),
        ),
    )


def find_patches_from_single_pattern(pattern, lines, updater):
    """
    Searches the given lines for matches to the given pattern and yields a "patch"
    for each subset of lines that are updated by the given updater function.

    For each match to the pattern, the minimal selection of lines that completely
    contains that match is selected and passed to the updater to obtain updated lines.
    A "patch" is then yielded that contains the updated lines along with the start and
    end line numbers from the original lines.

    :param pattern:
    :param lines:
    :param updater:
    :return:
    """
    # Use the keys of an OrderedDict (and ignore the values) as an approximation for
    # an OrderedSet. The set properties allow de-duplication of line selections that
    # may occur when the pattern matches more than once on any given line, and the
    # ordered property enables us to yield patches in the same order that they are
    # found (i.e. top-down).
    matches = OrderedDict()
    combined_lines = ''.join(lines)
    for match, start, end in finditer_with_line_numbers(pattern, combined_lines):
        matches[(
            start,
            end,
            ''.join(lines[start:end]),
        )] = match

    for match_context, match in reversed(list(matches.iteritems())):
        start, end, patch_lines = match_context
        patch_lines = split_lines_by_newline_but_retain_newlines(patch_lines)
        updated_lines = updater(patch_lines, match, lines[:start], lines[end:])
        if updated_lines is not None:
            yield start, end, updated_lines


def find_patches_from_pattern_sequence(patterns, lines, updater, validator=None):
    """
    Takes a set of single-line patterns and uses them to find all
    non-overlapping subsets of lines that match all of the patterns in order.

    In other words, the given lines are iterated over and tested against the
    first pattern. Once a match is found, the iteration continues but testing is
    performed against the second match, and so on until all patterns have been
    matched. The subset of lines that completely contain all matches are then
    selected and passed through the given updater function in order to yield a
    "patch". Then, the matching restarts with the first pattern on the next
    line.

    Every "patch" that is yielded contains the updated lines along with the
    start and end line numbers from the original lines.

    :param pattern:
    :param lines:
    :param updater:
    :return:
    """
    current_pattern_i = 0
    patch_start = None
    patch_end = None
    patch_lines_by_number = OrderedDict()
    patch_matches = []

    line_number = 0
    while line_number < len(lines):
        line = lines[line_number]
        while re.search(patterns[current_pattern_i], line):
            match = re.search(patterns[current_pattern_i], line)
            patch_lines_by_number[line_number] = line
            patch_matches.append(match)

            if not patch_start:
                patch_start = line_number

            if patterns[current_pattern_i] == patterns[-1]:
                patch_lines = patch_lines_by_number.values()
                if validator and not validator(patch_lines, patch_matches):
                    # False positive. Ignore this patch and move the iterator
                    # back to the start of this patch. The end of the outer loop
                    # will then increment, effectively starting the search over
                    # at the line just after the start of this patch.
                    line_number = patch_start
                    current_pattern_i = 0
                    patch_start = None
                    patch_end = None
                    patch_lines_by_number = OrderedDict()
                    patch_matches = []
                    break

                patch_end = line_number + 1
                updated_lines = updater(
                    patch_lines_by_number.values(),
                    patch_matches,
                    lines[:patch_start],
                    lines[patch_end:],
                )
                if updated_lines is not None:
                    yield patch_start, patch_end, updated_lines
                current_pattern_i = 0
                patch_start = None
                patch_end = None
                patch_lines_by_number = OrderedDict()
                patch_matches = []
                break

            current_pattern_i += 1

        if patch_start is not None:
            patch_lines_by_number[line_number] = line

        line_number += 1


def finditer_with_line_numbers(pattern, string, flags=0):
    """
    A version of 're.finditer' that returns '(match, line_number)' pairs.
    """
    matches = list(re.finditer(pattern, string, flags))
    if not matches:
        return

    end = matches[-1].start()
    # -1 so a failed 'rfind' maps to the first line.
    newline_table = {-1: 0}
    for i, m in enumerate(re.finditer(r'\n', string), 1):
        # don't find newlines past our last match
        offset = m.start()
        if offset > end:
            break
        newline_table[offset] = i

    # Failing to find the newline is OK, -1 maps to 0.
    for m in matches:
        newline_offset = string.rfind('\n', 0, m.start())
        start_line_number = newline_table[newline_offset]
        end_line_number = start_line_number + \
            len(re.findall(r'\n', m.group(0))) + 1
        yield (m, start_line_number, end_line_number)


def get_last_directive_line_number(lines):
    last_directive_line_number = -1
    for line_number, line in enumerate(lines):
        match = re.search(regexes.DIRECTIVE_REGEX, line)
        if match:
            directive_end_line_number = line_number
            while not lines[directive_end_line_number].endswith(';\n'):
                directive_end_line_number += 1
            last_directive_line_number = directive_end_line_number

    return last_directive_line_number


def get_line_number_to_insert_parts(lines):
    last_directive_line_number = get_last_directive_line_number(lines)
    if last_directive_line_number != -1:
        return last_directive_line_number + 1
    return len(lines)


def get_props_or_state_meta_const(class_name, meta_type):
    return 'static const {meta_type} meta = $metaFor{class_name};'.format(
        class_name=class_name,
        meta_type=meta_type,
    )


def get_meta_const_ignore_line():
    return '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n'


def get_meta_type(annotation):
    return 'PropsMeta' if 'Props' in annotation else 'StateMeta'


def is_dart_file(path):
    """
    Determines if the given path is a Dart file.
    """
    return path.endswith('.dart')


def needs_factory_update(lines):
    combined_lines = ''.join(lines)
    return re.search(regexes.FACTORY_REGEX, combined_lines) is not None


def needs_over_react_generated_part(lines):
    for line in lines:
        if re.search(regexes.NEEDS_GENERATED_PART_REGEX, line):
            return True
    return False


def parse_factory_name(s):
    """
    Get the factory name from a line that is known to include a factory
    definition.

    >>> parse_factory_name('UiFactory<DemoProps> Demo;')
    'Demo'
    """
    match = re.search(regexes.FACTORY_REGEX, s)
    return match.group(1) if match else None


def parse_library_name(lines):
    match = search_pattern_over_one_or_two_lines(
        regexes.LIBRARY_NAME_REGEX, lines)
    return match.group(1) if match else None


def parse_part_of_name(lines):
    match = search_pattern_over_one_or_two_lines(
        regexes.PART_OF_NAME_REGEX, lines)
    return match.group(1) if match else None


def parse_part_of_uri(lines):
    match = search_pattern_over_one_or_two_lines(
        regexes.PART_OF_URI_REGEX, lines)
    return match.group(1) if match else None


def parse_part_paths(lines):
    for line in lines:
        match = re.search(regexes.PART_REGEX, line)
        if match:
            yield match.group(1)


def search_pattern_over_one_or_two_lines(pattern, lines):
    prev_line = None
    for i, line in enumerate(lines):
        # First, search over the single line
        match = re.search(pattern, line)
        if match:
            return match

        # Second, search over the current and previous line
        if prev_line:
            two_lines = ''.join([prev_line, line])
            match = re.search(pattern, two_lines)
            if match:
                return match

        prev_line = line
    return None


def split_lines_by_newline_but_retain_newlines(s):
    return ['%s\n' % line for line in s.split('\n')[:-1]]
