from ..regexes import DOLLAR_PROPS_REGEX
from ..regexes import DOLLAR_PROP_KEYS_REGEX
from ..updaters import update_dollar_props
from ..updaters import update_dollar_prop_keys
from .util import suggest_patches


def dollar_props_suggestor(lines, _):
    for patch in suggest_patches(
        DOLLAR_PROPS_REGEX,
        lines,
        update_dollar_props,
    ):
        yield patch

    for patch in suggest_patches(
        DOLLAR_PROP_KEYS_REGEX,
        lines,
        update_dollar_prop_keys,
    ):
        yield patch
