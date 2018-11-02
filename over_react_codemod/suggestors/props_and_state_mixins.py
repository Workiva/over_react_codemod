from ..regexes import PROPS_OR_STATE_MIXIN_REGEX
from ..updaters import rename_props_or_state_mixin
from .util import suggest_patches


def props_and_state_mixins_suggestor(lines, _):
    # Rename props and state mixins
    for patch in suggest_patches(
            PROPS_OR_STATE_MIXIN_REGEX,
            lines,
            rename_props_or_state_mixin,
    ):
        yield patch
