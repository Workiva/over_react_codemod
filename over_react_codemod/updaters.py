import re

from . import regexes
from . import util


def add_public_props_or_state_class_boilerplate(lines, matches, prev_lines, next_lines):
    annotation_match = matches[0]
    class_decl_match = matches[1]

    annotation = annotation_match.group(1)
    is_abstract = class_decl_match.group(1) is not None
    class_name = class_decl_match.group(2).strip()

    if class_name.startswith('_$'):
        # This props/state class has already been renamed/codemodded. Strip the
        # prefix and continue to ensure that the accompanying class is there.
        class_name = class_name.replace('_$', '')

    for line in next_lines:
        options = [
            'abstract class %s ' % class_name,
            'abstract class %s<' % class_name,
            'class %s ' % class_name,
            'class %s<' % class_name,
        ]
        for option in options:
            if line.startswith(option):
                # if re.match(r'(abstract\s+)?class\s+' + class_name + r'[\s<]', line):
                # Accompanying class already added.
                return None

    class_rename = util.prefix_name(class_name)
    accessors_mixin_name = util.prefix_name(class_name + 'AccessorsMixin')
    meta_type = util.get_meta_type(annotation)

    public_class_signature = '{abstract}class {class_name} extends {super_class_name} with {mixin_name}'.format(
        abstract='abstract ' if is_abstract else '',
        class_name=class_name,
        mixin_name=accessors_mixin_name,
        super_class_name=class_rename,
    )
    props_meta_impl = util.get_props_or_state_meta_const(class_name, meta_type)

    return [
        '\n',
        '// AF-3369 This will be removed once the transition to Dart 2 is complete.\n',
        '// ignore: mixin_of_non_class, undefined_class\n',
        '%s {\n' % public_class_signature,
        util.get_meta_const_ignore_line(),
        '  %s\n' % props_meta_impl,
        '}\n',
    ]


def insert_props_or_state_meta(lines, matches, prev_lines, next_lines):
    for line in next_lines[:6]:
        if re.match(r'\s*static const (Props|State)Meta meta =', line):
            # Already updated.
            return None

    annotation_match = matches[0]
    meta_type = util.get_meta_type(annotation_match.group(1))

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
            '  // To ensure the codemod regression checking works properly, please keep this\n',
            '  // field at the top of the class!\n',
            '  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value\n',
            '  %s\n' % util.get_props_or_state_meta_const(
                class_name, meta_type),
            '}\n' if needs_closing_brace else '\n',
        ])

    return new_lines


def rename_props_or_state_class(lines, matches, prev_lines, next_lines):
    class_decl_match = matches[1]
    class_decl_line = class_decl_match.group(0)
    class_name = class_decl_match.group(2)
    if class_name.startswith('_$'):
        # Class has already been renamed.
        return lines

    is_private = class_name.startswith('_')
    new_name = '_$%s' % (class_name[1:] if is_private else class_name)

    new_lines = []
    for line in lines:
        if not line.startswith(class_decl_line):
            new_lines.append(line)
            continue

        updated_line = line.replace(
            'class %s' % class_name, 'class %s' % new_name)
        new_lines.append(updated_line)

    return new_lines


def rename_props_or_state_mixin(lines, match, prev_lines, next_lines):
    combined = ''.join(lines)
    class_name = match.group(1)
    pattern = (
        r'class\s+'
        '%s' % class_name
    )
    updated = re.sub(pattern, 'class $%s' % class_name, combined)
    updated_lines = util.split_lines_by_newline_but_retain_newlines(updated)
    updated_lines.insert(
        1, '// AF-3369 This will be made private once the transition to Dart 2 is complete.\n')
    return updated_lines


def update_component_default_props(lines, match, prev_lines, next_lines):
    combined = ''.join(lines)
    updated = re.sub(regexes.COMPONENT_DEFAULT_PROPS_REGEX,
                     r'\1().componentDefaultProps', combined)
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_dollar_props(lines, match, prev_lines, next_lines):
    updated = re.sub(regexes.DOLLAR_PROPS_REGEX, r'\1.meta', ''.join(lines))
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_dollar_prop_keys(lines, match, prev_lines, next_lines):
    updated = re.sub(regexes.DOLLAR_PROP_KEYS_REGEX,
                     r'\1.meta.keys', ''.join(lines))
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_factory(lines, match, prev_lines, next_lines):
    combined = ''.join(lines)
    factory_name = match.group(1)
    is_private = factory_name.startswith('_')
    initializer = '_$%s' % factory_name[1:] if is_private else '$%s' % factory_name
    updated = combined.replace(
        '%s;' % factory_name, '%s = %s;' % (factory_name, initializer))
    updated = '// ignore: undefined_identifier\n' + updated
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_props_or_state_mixin_usage(lines, matches, prev_lines, next_lines):
    mixins = ''
    with_started = False

    for line in lines:
        if not with_started and re.search(regexes.WITH_CLAUSE_START_REGEX, line):
            with_started = True

        if not with_started:
            continue

        s = re.sub(regexes.WITH_CLAUSE_START_REGEX, r'', line)
        s = re.sub(regexes.WITH_CLAUSE_END_REGEX, r'', s)
        mixins += s

        if re.search(regexes.WITH_CLAUSE_END_REGEX, line):
            break

    # Strip last trailing newline char.
    mixins = mixins[:-1]

    for line in mixins.split('\n'):
        if re.match(r'\s*// ignore: mixin_of_non_class', line):
            # Already updated.
            return None

    replace_pattern = (
        r'\n'
        r'    \1\2\3,\n'
        r'    // ignore: mixin_of_non_class, undefined_class\n'
        r'    $\1\2\3'
    )
    updated_mixins = str(
        re.sub(r'(\w+)(PropsMixin|StateMixin)([<\w>]*)', replace_pattern, mixins))
    if updated_mixins == mixins:
        return

    combined = ''.join(lines)
    updated = re.sub(
        r'(\s+with[\S\s]+)' + re.escape(mixins), r'\1' + updated_mixins, combined)

    return util.split_lines_by_newline_but_retain_newlines(updated)


def validate_props_or_state_mixin_usage_patch(lines, matches):
    if re.search(regexes.COMMENT_LINE_REGEX, lines[0]):
        # First line matched on a comment, ignore it.
        return False

    # Track these so we can find a false positive where `with` may have matched
    # outside of a class declaration.
    with_clause_started = False
    class_body_started = False

    for line in lines:
        is_comment = re.search(regexes.COMMENT_LINE_REGEX, line)
        with_clause_start_match = re.search(
            regexes.WITH_CLAUSE_START_REGEX, line)
        class_body_start_match = re.search(
            regexes.CLASS_BODY_BRACES_REGEX, line)

        if is_comment and with_clause_start_match:
            # with clause matched on a comment
            return False

        if is_comment:
            continue

        if not with_clause_started and with_clause_start_match:
            with_clause_started = True
        if not class_body_started and class_body_start_match:
            class_body_started = True

        if class_body_started and not with_clause_started:
            # False positive. Matched on a with clause outside of the class.
            return False

    return True
