from ..regexes import COMPONENT_DEFAULT_PROPS_REGEX
from ..updaters import update_component_default_props
from .util import suggest_patches_from_single_pattern


def component_default_props_suggestor(lines, _):
    for patch in suggest_patches_from_single_pattern(
        COMPONENT_DEFAULT_PROPS_REGEX,
        lines,
        update_component_default_props,
    ):
        yield patch
