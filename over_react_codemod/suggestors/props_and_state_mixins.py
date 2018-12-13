from ..regexes import CLASS_BODY_BRACES_REGEX, PROPS_OR_STATE_MIXIN_REGEX, PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import insert_props_or_state_meta, rename_props_or_state_mixin
from ..util import get_props_or_state_meta_const, get_meta_type, eprint, get_meta_const_ignore_line
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern
import re
import codemod

# Disabled. Decided that consumer-defined mixins need to remain unchanged
# until after the transition is complete.
# def props_and_state_mixins_suggestor(lines, _):
#     # Rename props and state mixins
#     for patch in suggest_patches_from_single_pattern(
#             PROPS_OR_STATE_MIXIN_REGEX,
#             lines,
#             rename_props_or_state_mixin,
#     ):
#         yield patch


def props_and_state_mixins_meta_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
            CLASS_BODY_BRACES_REGEX,
        ),
        lines,
        insert_props_or_state_meta,
    ):
        yield patch
