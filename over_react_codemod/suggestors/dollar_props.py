from ..regexes import DOLLAR_PROPS_REGEX
from ..regexes import DOLLAR_PROP_KEYS_REGEX
from ..updaters import update_dollar_props
from ..updaters import update_dollar_prop_keys
from .util import suggest_patches_from_single_pattern


def dollar_props_suggestor(lines, _):
    for patch in suggest_patches_from_single_pattern(
        DOLLAR_PROPS_REGEX,
        lines,
        update_dollar_props,
    ):
        yield patch

    for patch in suggest_patches_from_single_pattern(
        DOLLAR_PROP_KEYS_REGEX,
        lines,
        update_dollar_prop_keys,
    ):
        yield patch
