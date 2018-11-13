from ..regexes import PROPS_OR_STATE_MIXIN_REGEX, PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import rename_props_or_state_mixin
from ..util import get_props_or_state_meta_const, get_meta_type, eprint, get_meta_const_ignore_line
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern
import re
import codemod


def props_and_state_mixins_suggestor(lines, _):
    # Rename props and state mixins
    for patch in suggest_patches_from_single_pattern(
            PROPS_OR_STATE_MIXIN_REGEX,
            lines,
            rename_props_or_state_mixin,
    ):
        yield patch


def props_and_state_mixins_meta_suggestor(lines, _):
    patterns = [
        PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX,
        CLASS_DECLARATION_REGEX,
        re.compile(r'.*{(})?$', flags=re.MULTILINE),
    ]

    def updater(lines, matches, prev_lines, next_lines):
        for line in next_lines[:3]:
            if re.match(r'  static const (Props|State)Meta meta =', line):
                # Already updated.
                return lines

        annotation_match = matches[0]
        meta_type = get_meta_type(annotation_match.group(1))

        class_decl_match = matches[1]
        class_name = class_decl_match.group(2)

        class_body_open_match = matches[2]
        class_body_open_line = class_body_open_match.group(0)

        new_lines = []
        for line in lines:
            if not line.startswith(class_body_open_line):
                new_lines.append(line)
                continue

            needs_closing_brace = False
            if line.endswith('{}\n'):
                # Strip the closing body curly brace
                line = line.replace('{}', '{')
                needs_closing_brace = True

            new_lines.extend([
                line,
                '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
                '  %s\n' % get_props_or_state_meta_const(
                    class_name, meta_type),
                '}\n' if needs_closing_brace else '\n',
            ])

        return new_lines

    for patch in suggest_patches_from_pattern_sequence(patterns, lines, updater):
        yield patch
