#!/usr/bin/env python2

import os
import re

import codemod

demo_factory = 'UiFactory<DemoProps> Demo;'

def get_factory_props_name(line):
    name = re.search(r'UiFactory<(\w+)>', line).group(1)
    return name
assert get_factory_props_name(demo_factory) == 'DemoProps'

def get_factory_name(line):
    name = re.search(r' (\w+);', line).group(1)
    return name
assert get_factory_name(demo_factory) == 'Demo'

def get_part_name(path):
    name = os.path.split(path)[-1].replace('.dart', '')
    return name
assert get_part_name('./foo/bar/baz.dart') == 'baz'

# Maps library identifiers (foo.bar) to the parts that
# must be added to them (baz.g.dart).
libraries = {}

def collect_library(lines, part_name):
    count0 = len(libraries)
    for line in lines:
        name = re.search(r'part of ([\w.]+);', line)
        if name is not None:
            name = name.group(1)
            libraries[name] = part_name
    return count0 < len(libraries)
result = collect_library([
        'foo bar baz', 'part of foo.bar;', 'something'
    ], 'part')
assert result
assert libraries['foo.bar'] == 'part'

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
        part_filename = '%s.namespace.dart' % part_name
        
        # If we're not a part then we just need to declare our part.
        # Otherwise we'll need to make another pass and declare our
        # part in the library we are a part of.
        if not collect_library(lines, part_filename):
            ignore_line = '// ignore: uri_has_not_been_generated\n'
            part_line = 'part \'%s\';' % part_filename

            patches.append(codemod.Patch(0, new_lines=[
                ignore_line,
                part_line,
            ]))
        
    for patch in patches:
        yield patch

def use_path(path):
    return path.endswith('.dart')

q0 = codemod.Query(suggest, path_filter=use_path)

def parts_suggest(lines, _path):
    library_name = None
    library_line = ''
    library_line_number = 0
    for line_number, line in enumerate(lines):
        match = re.search(r'library ([\w.]+);', line)
        if match is not None:
            library_name = match.group(1)
            library_line = line
            library_line_number = line_number
            break
    if library_name is not None and libraries.has_key(library_name):
        yield codemod.Patch(library_line_number, new_lines=[
            library_line,
            'part \'%s\'\n' % libraries[library_name],
        ])

q1 = codemod.Query(parts_suggest, path_filter=use_path)

if __name__ == '__main__':
    codemod.run_interactive(q0)
    codemod.run_interactive(q1)

