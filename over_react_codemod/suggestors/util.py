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

import codemod

from over_react_codemod import util


def suggest_patches_from_single_pattern(pattern, lines, updater, insert_at_end=False):
    for start, end, new_lines in util.find_patches_from_single_pattern(pattern, lines, updater):
        if insert_at_end:
            start = len(lines)
            end = start
        yield codemod.Patch(
            start_line_number=start,
            end_line_number=end,
            new_lines=new_lines,
        )


def suggest_patches_from_pattern_sequence(patterns, lines, updater, insert_at_end=False, validator=None):
    for start, end, new_lines in util.find_patches_from_pattern_sequence(patterns, lines, updater, validator=validator):
        if insert_at_end:
            start = len(lines)
            end = start
        yield codemod.Patch(
            start_line_number=start,
            end_line_number=end,
            new_lines=new_lines,
        )
