import os

import codemod

from .. import util


libraries_that_need_generated_part_by_name = set([])
libraries_that_need_generated_part_by_path = set([])


def collect_libraries_suggestor(lines, path):
    if not util.needs_over_react_generated_part(lines):
        return []

    parent_library_name = util.parse_part_of_name(lines)
    parent_library_uri = util.parse_part_of_uri(lines)

    if parent_library_uri:
        # This file is a part file and has a parent library referenced by uri.
        if parent_library_uri.startswith('package:'):
            parent_library_relpath = util.convert_part_of_uri_to_relpath(parent_library_uri)
        else:
            parent_library_relpath = os.path.normpath(
                os.path.join(
                    # containing directory of this file
                    os.path.dirname(path),
                    # relative path from this file to parent library file
                    parent_library_uri,
                )
            )

        libraries_that_need_generated_part_by_path.add(parent_library_relpath)
    elif parent_library_name:
        # This file is a part file and has a parent library referenced by name.
        libraries_that_need_generated_part_by_name.add(parent_library_name)
    else:
        # This file is its own library, to which the generated part needs to be added.
        libraries_that_need_generated_part_by_path.add(path)

    return []


def generated_parts_suggestor(lines, path):
    library_name = util.parse_library_name(lines)

    needs_generated_part = (
        path in libraries_that_need_generated_part_by_path
        or (
            library_name
            and library_name in libraries_that_need_generated_part_by_name
        )
    )
    if not needs_generated_part:
        return

    generated_part_filename = util.build_generated_part_filename(path)
    existing_part_paths = util.parse_part_paths(lines)
    if generated_part_filename in existing_part_paths:
        return

    line_number_to_insert_parts = util.get_line_number_to_insert_parts(lines)
    new_lines = [
        '\n',
        '// ignore: uri_has_not_been_generated\n',
        "part '%s';\n" % generated_part_filename,
    ]

    yield codemod.Patch(
        start_line_number=line_number_to_insert_parts,
        end_line_number=line_number_to_insert_parts,
        new_lines=new_lines,
    )
