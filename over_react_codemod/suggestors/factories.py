from ..regexes import FACTORY_REGEX
from ..updaters import update_factory
from .util import suggest_patches_from_single_pattern


def factories_suggestor(lines, _):
    for patch in suggest_patches_from_single_pattern(
        FACTORY_REGEX,
        lines,
        update_factory,
    ):
        yield patch
