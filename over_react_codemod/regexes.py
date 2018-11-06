import re

COMPONENT_DEFAULT_PROPS_REGEX = re.compile(
    # constructor keyword + at least one whitespace char
    r'new\s+'
    # component class name
    # (GROUP 1)
    r'(\w+)Component'
    # parens + optional whitespace
    r'\(\)\s*'
    # getDefaultProps() invocation
    r'\.getDefaultProps\(\)'
)

DART_EXTENSION_REGEX = re.compile(
    r'\.dart$'
)

# TODO test
DOLLAR_PROPS_REGEX = re.compile(
    # constructor keyword + at least one whitespace char
    r'(?:const|new)\s+'
    # optional over_react import prefix + optional whitespace
    r'(?:\w+\s*\.\s*)?'
    # $Props constructor + optional whitespace
    r'\$Props\s*'
    # opening paren + optional whitespace
    r'\(\s*'
    # props arg, including optional import prefix
    # (GROUP 1)
    r'([\w$.]+)'
    # optional whitespace + optional trailing comma + optional whitespace
    r'\s*(?:,)?\s*'
    # closing paren
    r'\)',
)

# TODO test
DOLLAR_PROP_KEYS_REGEX = re.compile(
    # constructor keyword + at least one whitespace char
    r'(?:const|new)\s+'
    # optional over_react import prefix + optional whitespace
    r'(?:\w+\s*\.\s*)?'
    # $PropKeys constructor + optional whitespace
    r'\$PropKeys\s*'
    # opening paren + optional whitespace
    r'\(\s*'
    # props arg, including optional import prefix
    # (GROUP 1)
    r'([\w$.]+)'
    # optional whitespace + optional trailing comma + optional whitespace
    r'\s*(?:,)?\s*'
    # closing paren
    r'\)',
)

DIRECTIVE_REGEX = re.compile(
    r'''^(?:(?:(?:import|export|part)\s+['\"])|library\s+\w)'''
)

FACTORY_REGEX = re.compile(
    # UiFactory type (must be at beginning of line) + optional whitespace
    r'^UiFactory\s*'
    # optional generic arg (including optional nested generics) + optional whitespace
    r'(?:<\s*[<>\w\s]+\s*>)?'
    # at least one whitespace char after the type
    r'\s+'
    # factory name + semicolon
    # (GROUP 1)
    r'(\w+);',
    flags=re.MULTILINE,
)

LIBRARY_NAME_REGEX = re.compile(
    r'^library\s+([.\w]+);',
    flags=re.MULTILINE,
)

NEEDS_GENERATED_PART_REGEX = re.compile(
    r'^(?:@Factory\(\)|@(?:Abstract)?(?:Props|State|Component)(?:Mixin)?\(\))',
    flags=re.MULTILINE,
)

PACKAGE_URI_PREFIX_REGEX = re.compile(
    r'^package:\w+/',
    flags=re.MULTILINE,
)

PART_OF_NAME_REGEX = re.compile(
    r'^part\s+of\s+([\w.]+);',
    flags=re.MULTILINE,
)

PART_OF_URI_REGEX = re.compile(
    r'''^part\s+of\s+['\"](.+)['\"];''',
    flags=re.MULTILINE,
)

PART_REGEX = re.compile(
    r'''^part\s+['\"](.+)['\"];''',
    flags=re.MULTILINE,
)

PROPS_OR_STATE_ANNOTATION_REGEX= re.compile(
    r'^@(Props|AbstractProps|State|AbstractState)\('
)

CLASS_DECLARATION_REGEX = re.compile(
    r'^(abstract )?class ([\w$]+)'
)

# Groups:
# 1 = props or state annotation
# 2 = non-empty if class is abstract
# 3 = class name
PROPS_OR_STATE_CLASS_REGEX = re.compile(
    # Abstract or concrete props and state annotations:
    # - @Props()
    # - @AbstractProps()
    # - @State()
    # - @AbstractState()
    r'^@(Props|AbstractProps|State|AbstractState)\(\)'
    # optional whitespace or comments or other annotations
    r'[\s.]*'
    # optional abstract keyword
    r'^(abstract\s+)?'
    # class name including optional generic params
    r'class\s+([\w\s<>,]+)'
    # extends clause including optional generic args
    r'extends\s+(?:[\w\s<>,]+)'
    # with clause including optional generic args
    r'(?:with\s+(?:[\w\s<>,]+))?'
    # everything else (e.g. implements clause) up to the opening curly brace
    r'[\s.]*{',
    flags=re.MULTILINE,
)

PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX = re.compile(
    r'^@(?:PropsMixin|StateMixin)\('
)

# Groups:
# 1 = class name
PROPS_OR_STATE_MIXIN_REGEX = re.compile(
    # Props and state mixin annotations:
    # - @PropsMixin()
    # - @StateMixin()
    r'^@(?:PropsMixin|StateMixin)\(\)'
    # optional whitespace or comments or other annotations
    r'[\s.]*'
    # optional abstract keyword
    r'^(?:abstract\s+)?'
    # class name including optional generic params
    r'class\s+([\w\s<>,]+)'
    # everything else (e.g. implements clause) up to the opening curly brace
    r'[\s.]*{',
    flags=re.MULTILINE,
)

# Groups:
# 1 = with clause (excluding the with keyword), guaranteed to include at least one
#     mixin that ends in PropsMixin or StateMixin.
WITH_PROPS_OR_STATE_MIXIN_REGEX = re.compile(
    # beginning of the with clause
    r'with\s+'
    # mixins, searching for at least one props or state mixin (by naming convention)
    r'(.*(?:PropsMixin|StateMixin).*)'
    # trailing whitespace
    r'\s*'
    # end of the with clause (either the start of the implements clause or the class body)
    r'(?:implements|\{)'
)
