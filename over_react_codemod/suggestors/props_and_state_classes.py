from ..regexes import PROPS_OR_STATE_CLASS_REGEX, PROPS_OR_STATE_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import add_public_props_or_state_class_boilerplate, rename_props_or_state_class
from ..util import eprint
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern
import re
import codemod


def props_and_state_classes_accompanying_public_class_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
        ),
        lines,
        add_public_props_or_state_class_boilerplate,
        insert_at_end=True,
    ):
        yield patch


def props_and_state_classes_rename_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
        ),
        lines,
        rename_props_or_state_class,
    ):
        yield patch
