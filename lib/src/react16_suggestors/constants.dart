// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const fixmePrefix = 'FIXME:over_react_codemod';

const manualValidationCommentSubstring = 'Check this box upon manual';

const willBeRemovedCommentSuffix =
    ' This will be removed once the transition to React 16 is complete.';

const styleMapExample = '''
    // CSS number strings are no longer auto-converted to px. Ensure values are of type `num`, or have units.
    // Incorrect value for 'width': '40'. Correct values: 40, '40px', '4em'.''';
