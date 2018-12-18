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
