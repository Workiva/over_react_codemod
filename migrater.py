#!/usr/bin/env python2

import os
import re

import codemod

IGNORE_GENERATED_URI_COMMENT_LINE = '// ignore: uri_does_not_exist\n'
GENERATED_PART_EXTENSION = '.generated.dart'
DOLLAR_PROPS_USAGE_REGEX = r'(?:const|new)\s+\$Props\s*\(\s*([$A-Za-z0-9_.]+)\s*\)'
DOLLAR_PROP_KEYS_USAGE_REGEX = r'(?:const|new)\s+\$PropKeys\s*\(\s*([$A-Za-z0-9_.]+)\s*\)'
FACTORY_REGEX = r'^UiFactory(<\w+>) (\w+);'


def get_class_name(line):
    """
    Get the class name from a line that is known to include a class definition.

    >>> get_class_name('class FooProps extends UiProps {')
    'FooProps'
    """
    name = re.search(r'^class (\w+)', line).group(1)
    if not name:
        name = re.search(r'^abstract class (\w+)', line).group(1)
    return name


def get_factory_name(line):
    """
    Get the factory name from a line that is known to include a factory
    definition.

    >>> get_factory_name('UiFactory<DemoProps> Demo;')
    'Demo'
    """
    match = re.search(FACTORY_REGEX, line)
    if not match:
        raise Exception('Could not parse factory name from:\n%s' % line)
    return match.group(2)


def get_part_name(path):
    """
    Get the expected part name from a file path.

    >>> get_part_name('./foo/bar/baz.dart')
    'baz'
    """
    name = os.path.split(path)[-1].replace('.dart', '')
    return name


def needs_factory_update(line):
    return re.search(FACTORY_REGEX, line) is not None


def get_part_path(path):
    """
    Get the expected part name from a file path.

    >>> get_part_name('./foo/bar/baz.dart')
    'baz'
    """
    split_path = os.path.split(path)
    directory = os.path.join(*split_path[:-1])
    name = split_path[-1].replace('.dart', GENERATED_PART_EXTENSION)
    return os.path.join(directory, name)


def get_last_directive_line_number(lines):
    last_directive_line_number = -1
    for line_number, line in enumerate(lines):
        match = re.search(r'''^(?:(?:(?:part|import|export)\s+['"])|library\s+\w)''', line)
        if match:
            last_directive_line_number = line_number
    return last_directive_line_number


def get_line_number_to_insert_part(lines):
    last_directive_line_number = get_last_directive_line_number(lines)
    if last_directive_line_number != -1:
        return last_directive_line_number + 1
    return len(lines)


def has_dollar_props_usages(lines):
    s = ''.join(lines)
    return re.search(DOLLAR_PROPS_USAGE_REGEX, s, flags=re.MULTILINE) is not None


def has_dollar_prop_keys_usages(lines):
    s = ''.join(lines)
    return re.search(DOLLAR_PROP_KEYS_USAGE_REGEX, s, flags=re.MULTILINE) is not None


def update_dollar_props_usages(lines):
    s = ''.join(lines)
    match = re.search(DOLLAR_PROPS_USAGE_REGEX, s, flags=re.MULTILINE)
    before = match.group(0)
    after = '%s.meta' % match.group(1)
    s = s.replace(before, after)
    return ['%s\n' % line for line in s.split('\n')[:-1]]


def update_dollar_prop_keys_usages(lines):
    s = ''.join(lines)
    match = re.search(DOLLAR_PROP_KEYS_USAGE_REGEX, s, flags=re.MULTILINE)
    before = match.group(0)
    after = '%s.meta.keys' % match.group(1)
    s = s.replace(before, after)
    return ['%s\n' % line for line in s.split('\n')[:-1]]


# Maps library identifiers (foo.bar) to the parts that
# must be added to them (baz.g.dart).
part_paths_by_library_name = {}


def collect_library(lines, part_path):
    """
    Determine which library the current file is a part of and remember it.

    >>> result = collect_library([
    ...     'foo bar baz',
    ...     'part of foo.bar;',
    ...     'something'
    ... ], 'part')
    >>> result
    True
    >>> libraries['foo.bar']
    'part'
    """
    for line in lines:
        name = re.search(r'part of ([_\w\.]+);', line)
        if name is not None:
            name = name.group(1)
            part_paths_by_library_name.setdefault(name, []).append(part_path)
            return True
    return False


def factories_suggest(lines, path):
    patches = []
    need_part = False

    for line_number, line in enumerate(lines):
        if needs_factory_update(line):
            factory_name = get_factory_name(line)
            
            need_part = True

            ignore_line = '// ignore: undefined_identifier\n'
            new_line = line.replace(';\n', ' = $%s;\n' % factory_name)

            patches.append(codemod.Patch(line_number, new_lines=[
                ignore_line,
                new_line,
            ]))

    if need_part:
        part_name = get_part_name(path)
        part_path = get_part_path(path)
        part_filename = '%s%s' % (part_name, GENERATED_PART_EXTENSION)

        get_last_directive_line_number

        # If we're not a part then we just need to declare our part.
        # Otherwise we'll need to make another pass and declare our
        # part in the library we are a part of.
        if not collect_library(lines, part_path):
            part_line = 'part \'%s\';\n' % part_filename

            insert_line_number = get_line_number_to_insert_part(lines)
            patches.append(codemod.Patch(insert_line_number,
                end_line_number=insert_line_number,
                new_lines=[
                    '\n',
                    IGNORE_GENERATED_URI_COMMENT_LINE,
                    part_line,
                ]))

    for patch in patches:
        yield patch


def use_path(path):
    """
    Determines if the given path is a Dart file.

    >>> use_path('foo/bar.dart')
    True
    >>> use_path('bar/baz.py')
    False
    """
    return path.endswith('.dart')


def parts_suggest(lines, _path):
    library_name = None
    for line_number, line in enumerate(lines):
        match = re.search(r'library ([\w.]+);', line)
        if match is not None:
            library_name = match.group(1)
            break

    if library_name is not None and part_paths_by_library_name.has_key(library_name):
        new_lines = []
        for part_path in part_paths_by_library_name[library_name]:
            containing_dir_path = os.path.join(*os.path.split(_path)[:-1])
            # This path needs to be relative from the libary
            relative_part_path = os.path.relpath(part_path, containing_dir_path)
            new_lines.append('part \'%s\'; %s' % (relative_part_path, IGNORE_GENERATED_URI_COMMENT_LINE))

        insert_line_number = get_line_number_to_insert_part(lines)
        # Parts need to go after all other directives; add them after the last part, or at the end of the file
        yield codemod.Patch(insert_line_number,
                            end_line_number=insert_line_number,
                            new_lines=new_lines)


def props_metas_suggest(lines, path):
    for line_number, line in enumerate(lines):
        if line.startswith('@Props('):
            offset = 0
            found_class_opening = False
            class_body_is_empty = False
            props_class_name = None
            ignore_line = '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n'

            if ignore_line in lines:
                continue 

            for o, line_b in enumerate(lines[line_number:]):
                if line_b.startswith('class ') or line_b.startswith('abstract class '):
                    found_class_opening = True
                    props_class_name = get_class_name(line_b)

                if found_class_opening:
                    if line_b.endswith('{\n'):
                        offset = o
                        break

                    if line_b.endswith('{}\n'):
                        offset = o
                        class_body_is_empty = True
                        break

            if not props_class_name:
                continue

            last_class_def_line = lines[line_number + offset]
            if class_body_is_empty:
                last_class_def_line = last_class_def_line.replace('{}\n', '{\n')

            meta_line = '  static const PropsMeta meta = $metaFor%s;\n' % props_class_name
            # debug_line = 'line endings: %s' % line_endings

            new_lines = [
                last_class_def_line,
                ignore_line,
                meta_line,
            ]

            if class_body_is_empty:
                new_lines.append('}\n')
            else:
                new_lines.append('\n')

            yield codemod.Patch(line_number + offset, new_lines=new_lines)


def dollar_props_suggest(lines, path):
    for line_number, line in enumerate(lines):

        if not has_dollar_props_usages([line]):
            continue

        new_lines = update_dollar_props_usages([line])

        yield codemod.Patch(line_number, new_lines=new_lines)


def dollar_prop_keys_suggest(lines, path):
    for line_number, line in enumerate(lines):

        if not has_dollar_prop_keys_usages([line]):
            continue

        new_lines = update_dollar_prop_keys_usages([line])

        yield codemod.Patch(line_number, new_lines=new_lines)


def dollar_props_multiline_suggest(lines, path):
    for line_number, line in enumerate(lines):

        # A $Props() usage can be spread across at most 3 lines
        lines_subset = lines[line_number:line_number + 3]
        if not has_dollar_props_usages(lines_subset):
            continue

        new_lines = update_dollar_props_usages(lines_subset)

        # It may not have actually changed the 1st line.
        # If that's the case, don't change it for no reason.
        start_line_number = line_number
        end_line_number = start_line_number + 3
        if new_lines[0] == lines_subset[0]:
            start_line_number += 1
            new_lines = new_lines[1:]

        yield codemod.Patch(start_line_number,
                            end_line_number=end_line_number,
                            new_lines=new_lines)


def dollar_prop_keys_multiline_suggest(lines, path):
    for line_number, line in enumerate(lines):

        # A $PropKeys() usage can be spread across at most 3 lines
        lines_subset = lines[line_number:line_number + 3]
        if not has_dollar_prop_keys_usages(lines_subset):
            continue

        new_lines = update_dollar_prop_keys_usages(lines_subset)

        # It may not have actually changed the 1st line.
        # If that's the case, don't change it for no reason.
        start_line_number = line_number
        end_line_number = start_line_number + 3
        if new_lines[0] == lines_subset[0]:
            start_line_number += 1
            new_lines = new_lines[1:]

        yield codemod.Patch(start_line_number,
                            end_line_number=end_line_number,
                            new_lines=new_lines)


queries = [
    codemod.Query(factories_suggest, path_filter=use_path),
    codemod.Query(props_metas_suggest, path_filter=use_path),
    codemod.Query(dollar_props_suggest, path_filter=use_path),
    codemod.Query(dollar_props_multiline_suggest, path_filter=use_path),
    codemod.Query(dollar_prop_keys_suggest, path_filter=use_path),
    codemod.Query(dollar_prop_keys_multiline_suggest, path_filter=use_path),
    codemod.Query(parts_suggest, path_filter=use_path),
]


if __name__ == '__main__':
    for query in queries:
        codemod.run_interactive(query)
