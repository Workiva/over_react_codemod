import codemod

from over_react_codemod.suggestors.component_default_props import component_default_props_suggestor
from over_react_codemod.suggestors.dollar_props import dollar_props_suggestor
from over_react_codemod.suggestors.factories import factories_suggestor
from over_react_codemod.suggestors.generated_parts import collect_libraries_suggestor
from over_react_codemod.suggestors.generated_parts import generated_parts_suggestor
from over_react_codemod.suggestors.props_and_state_classes import props_and_state_classes_accompanying_public_class_suggestor
from over_react_codemod.suggestors.props_and_state_classes import props_and_state_classes_rename_suggestor
from over_react_codemod.suggestors.props_and_state_mixins import props_and_state_mixins_suggestor
from over_react_codemod.suggestors.props_and_state_mixins import props_and_state_mixins_meta_suggestor
from over_react_codemod.suggestors.with_props_or_state_mixins import with_props_and_state_mixins_suggestor
from over_react_codemod.util import is_dart_file


if __name__ == '__main__':
    codemod.run_interactive(codemod.Query(
        factories_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        dollar_props_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        component_default_props_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        props_and_state_classes_accompanying_public_class_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        props_and_state_classes_rename_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        props_and_state_mixins_meta_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        with_props_and_state_mixins_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        collect_libraries_suggestor, path_filter=is_dart_file))
    codemod.run_interactive(codemod.Query(
        generated_parts_suggestor, path_filter=is_dart_file))

    # Disabled. Decided that consumer-defined mixins need to remain unchanged
    # until after the transition is complete.
    # codemod.run_interactive(codemod.Query(
    #     props_and_state_mixins_suggestor, path_filter=is_dart_file))
