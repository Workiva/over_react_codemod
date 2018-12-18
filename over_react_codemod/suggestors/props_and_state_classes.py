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

from ..regexes import PROPS_OR_STATE_CLASS_REGEX, PROPS_OR_STATE_ANNOTATION_REGEX, CLASS_DECLARATION_REGEX
from ..updaters import add_public_props_or_state_class_boilerplate, rename_props_or_state_class
from ..util import eprint
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern
import re
import codemod


def props_and_state_classes_accompanying_public_class_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
        ),
        lines,
        add_public_props_or_state_class_boilerplate,
        insert_at_end=True,
    ):
        yield patch


def props_and_state_classes_rename_suggestor(lines, _):
    for patch in suggest_patches_from_pattern_sequence(
        (
            PROPS_OR_STATE_ANNOTATION_REGEX,
            CLASS_DECLARATION_REGEX,
        ),
        lines,
        rename_props_or_state_class,
    ):
        yield patch
