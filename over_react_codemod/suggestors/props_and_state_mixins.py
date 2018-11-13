from ..regexes import PROPS_OR_STATE_MIXIN_REGEX, PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import rename_props_or_state_mixin
from .util import suggest_patches
from ..util import get_props_or_state_meta_const, get_meta_type, eprint, get_meta_const_ignore_line
import re
import codemod


def props_and_state_mixins_suggestor(lines, _):
    # Rename props and state mixins
    for patch in suggest_patches(
            PROPS_OR_STATE_MIXIN_REGEX,
            lines,
            rename_props_or_state_mixin,
    ):
        yield patch


def props_and_state_mixins_meta_suggestor(lines, _):
    # for start, end, new_lines in find_patches(PROPS_OR_STATE_ANNOTATION_REGEX, lines, identity):
    for line_number, outer_line in enumerate(lines):
        match = re.search(PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX, outer_line)
        if not match:
            continue
        annotation = match.group(0)
        meta_type = get_meta_type(annotation)

        for offset_from_end, line in enumerate(lines[line_number+1:]):
            eprint('here')
            match = re.search(CLASS_DECLARATION_REGEX, line)
            if match:
                class_name = match.group(2)

            match = re.search(r'{(})?', line)
            if match and class_name:
                new_lines = [
                    '\n',
                    get_meta_const_ignore_line(),
                    '  ' + get_props_or_state_meta_const(class_name, meta_type),
                    '\n'
                ]
                insert_meta_location = offset_from_end+1 + line_number+1
                yield codemod.Patch(start_line_number=insert_meta_location, end_line_number=insert_meta_location, new_lines=new_lines)
                break







