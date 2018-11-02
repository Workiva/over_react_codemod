from ..regexes import WITH_PROPS_OR_STATE_MIXIN_REGEX
from ..updaters import update_props_or_state_mixin_usage
from .util import suggest_patches


def with_props_and_state_mixins_suggestor(lines, _):
    # Rename props and state mixins
    for patch in suggest_patches(
            WITH_PROPS_OR_STATE_MIXIN_REGEX,
            lines,
            update_props_or_state_mixin_usage,
    ):
        yield patch
