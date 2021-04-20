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

import 'package:codemod/codemod.dart';

final RegExp dollarPropsPattern = RegExp(
    // constructor keyword + at least one whitespace char
    r'new\s+'
    // component class name
    // (GROUP 1)
    r'(\w+)Component'
    // parens + optional whitespace
    r'\(\)\s*'
    // getDefaultProps() invocation
    r'\.getDefaultProps\(\)');

/// Suggestor that migrates usages of the `getDefaultProps()` method on a
/// UI component class to the Dart 2-compatible alternative of using the
/// `componentDefaultProps` getter on the component's props class.
Stream<Patch> componentDefaultPropsMigrator(FileContext context) async* {
  for (final match in dollarPropsPattern.allMatches(context.sourceText)) {
    yield Patch(
      '${match.group(1)}().componentDefaultProps',
      match.start,
      match.end,
    );
  }
}
