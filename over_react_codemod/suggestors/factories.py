from ..regexes import FACTORY_REGEX
from ..updaters import update_factory
from .util import suggest_patches


def factories_suggestor(lines, _):
    for patch in suggest_patches(
        FACTORY_REGEX,
        lines,
        update_factory,
    ):
        yield patch
