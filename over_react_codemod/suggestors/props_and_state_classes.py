from ..regexes import PROPS_OR_STATE_CLASS_REGEX, PROPS_OR_STATE_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import add_public_props_or_state_class_boilerplate
from ..updaters import rename_props_or_state_class
from .util import suggest_patches
from ..util import find_patches, eprint
import re
import codemod



def props_and_state_classes_accompanying_public_class_suggestor(lines, _):
    # Add the accompanying public version of every (soon-to-be-renamed) props and state class
    for patch in suggest_patches(
            PROPS_OR_STATE_CLASS_REGEX,
            lines,
            add_public_props_or_state_class_boilerplate,
            insert_at_end=True,
    ):
        yield patch


def props_and_state_classes_rename_suggestor(lines, _):
    # Rename props and state classes
    # for patch in suggest_patches(
    #         PROPS_OR_STATE_CLASS_REGEX,
    #         lines,
    #         rename_props_or_state_class,
    # ):
    #     yield patch
    def identity(value):
        return value

    # for start, end, new_lines in find_patches(PROPS_OR_STATE_ANNOTATION_REGEX, lines, identity):
    for line_number, outer_line in enumerate(lines):
        if not re.search(PROPS_OR_STATE_ANNOTATION_REGEX, outer_line):
            continue

        for offset_from_end, line in enumerate(lines[line_number+1:]):
            match = re.search(CLASS_DECLARATION_REGEX, line)
            if match:
                if match.group(2).startswith(r'_$'):
                    break
                class_declaration_start = offset_from_end + line_number+1
                if match.group(1):
                    updated_line = re.sub(CLASS_DECLARATION_REGEX, r'\1class _$\2', line)
                else:
                    updated_line = re.sub(CLASS_DECLARATION_REGEX, r'class _$\2', line)


                yield codemod.Patch(start_line_number=class_declaration_start, end_line_number=class_declaration_start, new_lines=[updated_line])
                break






