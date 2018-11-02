from ..regexes import PROPS_OR_STATE_CLASS_REGEX
from ..updaters import add_public_props_or_state_class_boilerplate
from ..updaters import rename_props_or_state_class
from .util import suggest_patches


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
    for patch in suggest_patches(
            PROPS_OR_STATE_CLASS_REGEX,
            lines,
            rename_props_or_state_class,
    ):
        yield patch
