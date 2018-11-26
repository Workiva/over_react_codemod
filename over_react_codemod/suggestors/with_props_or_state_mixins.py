from ..regexes import PROPS_OR_STATE_MIXIN_REFERENCE_REGEX, WITH_CLAUSE_END_REGEX, WITH_CLAUSE_START_REGEX
from ..updaters import update_props_or_state_mixin_usage
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern


def with_props_and_state_mixins_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            WITH_CLAUSE_START_REGEX,
            PROPS_OR_STATE_MIXIN_REFERENCE_REGEX,
            WITH_CLAUSE_END_REGEX,
        ),
        lines,
        update_props_or_state_mixin_usage,
    ):
        yield patch
