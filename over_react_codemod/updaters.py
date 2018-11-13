import re

from . import regexes
from . import util

def add_public_props_or_state_class_boilerplate(lines):
    combined = ''.join(lines)
    match = re.search(regexes.PROPS_OR_STATE_CLASS_REGEX, combined)
    annotation = match.group(1)
    is_abstract = match.group(2) is not None
    class_name = match.group(3).strip()

    private_class_name = '_$' + class_name
    accessors_mixin_name = '_$' + class_name + 'AccessorsMixin'
    meta_type = util.get_meta_type(annotation)

    public_class_signature = '{abstract}class {class_name} extends {super_class_name} with {mixin_name}'.format(
        abstract='abstract ' if is_abstract else '',
        class_name=class_name,
        mixin_name=accessors_mixin_name,
        super_class_name=private_class_name,
    )
    props_meta_impl = util.get_props_or_state_meta_const(class_name, meta_type)

    return [
        '\n',
        '// AF-#### This will be removed once the transition to Dart 2 is complete.\n',
        '// ignore: mixin_of_non_class, undefined_class\n',
        '%s {\n' % public_class_signature,
        util.get_meta_const_ignore_line(),
        '  %s\n' % props_meta_impl,
        '}\n',
    ]


def rename_props_or_state_class(lines):
    combined = ''.join(lines)
    match = re.search(regexes.PROPS_OR_STATE_CLASS_REGEX, combined)
    class_name = match.group(2)
    pattern = (
        r'class\s+'
        '%s' % class_name
    )
    updated = re.sub(pattern, 'class _$%s' % class_name, combined)
    return util.split_lines_by_newline_but_retain_newlines(updated)


def rename_props_or_state_mixin(lines):
    combined = ''.join(lines)
    match = re.search(regexes.PROPS_OR_STATE_MIXIN_REGEX, combined)
    class_name = match.group(1)
    pattern = (
        r'class\s+'
        '%s' % class_name
    )
    updated = re.sub(pattern, 'class $%s' % class_name, combined)
    updated_lines = util.split_lines_by_newline_but_retain_newlines(updated)
    updated_lines.insert(1, '// AF-#### This will be made private once the transition to Dart 2 is complete.\n')
    return updated_lines


def update_component_default_props(lines):
    # TODO: update all matches, not just first
    combined = ''.join(lines)
    factory_name = re.search(regexes.COMPONENT_DEFAULT_PROPS_REGEX, combined).group(1)
    updated = re.sub(regexes.COMPONENT_DEFAULT_PROPS_REGEX, '%s().componentDefaultProps' % factory_name, combined)
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_dollar_props(lines):
    # TODO: update all matches, not just first
    updated = re.sub(regexes.DOLLAR_PROPS_REGEX, r'\1.meta', ''.join(lines))
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_dollar_prop_keys(lines):
    # TODO: update all matches, not just first
    updated = re.sub(regexes.DOLLAR_PROP_KEYS_REGEX, r'\1.meta.keys', ''.join(lines))
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_factory(lines):
    combined = ''.join(lines)
    match = re.search(regexes.FACTORY_REGEX, combined)
    factory_name = match.group(1)
    updated = combined.replace('%s;' % factory_name, '%s = $%s;' % (factory_name, factory_name))
    updated = '// ignore: undefined_identifier\n' + updated
    return util.split_lines_by_newline_but_retain_newlines(updated)


def update_props_or_state_mixin_usage(lines):
    # NOTE: For simplicity, this implementation does NOT account for generics, and will probably function incorrectly
    # if used on a with clause that specifies generic type args.

    combined = ''.join(lines)
    match = re.search(regexes.WITH_PROPS_OR_STATE_MIXIN_REGEX, combined)
    with_clause = match.group(1)
    replace_pattern = (
        r'\n'
        r'    \1\2,\n'
        r'    // ignore: mixin_of_non_class, undefined_class\n'
        r'    $\1\2'
    )
    updated_with_clause = str(re.sub(r'(\w+)(PropsMixin|StateMixin)', replace_pattern, with_clause))
    updated = combined.replace(with_clause, updated_with_clause)
    util.eprint(len(util.split_lines_by_newline_but_retain_newlines(updated)))
    return util.split_lines_by_newline_but_retain_newlines(updated)
