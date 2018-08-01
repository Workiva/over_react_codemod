#!/usr/bin/env python2

import os
import re

import codemod

IGNORE_GENERATED_URI_COMMENT_LINE = '// ignore: uri_does_not_exist\n'
GENERATED_PART_EXTENSION = '.generated.dart'

def get_factory_name(line):
    """
    Get the factory name from a line that is known to include a factory
    definition.

    >>> get_factory_name('UiFactory<DemoProps> Demo;')
    'Demo'
    """
    name = re.search(r' (\w+);', line).group(1)
    return name


def get_part_name(path):
    """
    Get the expected part name from a file path.

    >>> get_part_name('./foo/bar/baz.dart')
    'baz'
    """
    name = os.path.split(path)[-1].replace('.dart', '')
    return name

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

# Maps library identifiers (foo.bar) to the parts that
# must be added to them (baz.g.dart).
parts_by_library_name = {}


def collect_library(lines, part_name):
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
            parts_by_library_name.setdefault(name, []).append(part_name)
            return True
    return False


def suggest(lines, path):
    patches = []
    need_part = False

    for line_number, line in enumerate(lines):
        if line.startswith('UiFactory'):
            need_part = True

            factory_name = get_factory_name(line)
            ignore_line = '// ignore: undefined_identifier\n'
            new_line = line.replace(';\n', ' = $%s;\n' % (factory_name))

            patches.append(codemod.Patch(line_number, new_lines=[
                ignore_line,
                new_line,
            ]))

    if need_part:
        part_name = get_part_name(path)
        part_filename = '%s%s' % (part_name, GENERATED_PART_EXTENSION)

        get_last_directive_line_number

        # If we're not a part then we just need to declare our part.
        # Otherwise we'll need to make another pass and declare our
        # part in the library we are a part of.
        if not collect_library(lines, part_filename):
            part_line = 'part \'%s\';\n' % part_filename

            insert_line_number = get_line_number_to_insert_part(lines)
            patches.append(codemod.Patch(insert_line_number,
                end_line_number=insert_line_number,
                new_lines=[
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

    if library_name is not None and parts_by_library_name.has_key(library_name):
        new_lines = []
        for part in parts_by_library_name[library_name]:
            new_lines.append('part \'%s\'; %s' % (part, IGNORE_GENERATED_URI_COMMENT_LINE))

        insert_line_number = get_line_number_to_insert_part(lines)
        # Parts need to go after all other directives; add them after the last part, or at the end of the file
        yield codemod.Patch(insert_line_number,
            end_line_number=insert_line_number,
            new_lines=new_lines)

q0 = codemod.Query(suggest, path_filter=use_path)
q1 = codemod.Query(parts_suggest, path_filter=use_path)

if __name__ == '__main__':
    codemod.run_interactive(q0)
    codemod.run_interactive(q1)
