# Copyright 2018 Workiva Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from ..regexes import CLASS_BODY_BRACES_REGEX, PROPS_OR_STATE_MIXIN_REGEX, PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import insert_props_or_state_meta, rename_props_or_state_mixin
from ..util import get_props_or_state_meta_const, get_meta_type, eprint, get_meta_const_ignore_line
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern
import re
import codemod

# Disabled. Decided that consumer-defined mixins need to remain unchanged
# until after the transition is complete.
# def props_and_state_mixins_suggestor(lines, _):
#     # Rename props and state mixins
#     for patch in suggest_patches_from_single_pattern(
#             PROPS_OR_STATE_MIXIN_REGEX,
#             lines,
#             rename_props_or_state_mixin,
#     ):
#         yield patch


def props_and_state_mixins_meta_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_MIXIN_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
            CLASS_BODY_BRACES_REGEX,
        ),
        lines,
        insert_props_or_state_meta,
    ):
        yield patch
