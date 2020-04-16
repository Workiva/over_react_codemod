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
import 'package:source_span/source_span.dart';

/// Suggestor that migrates usages of the `getDefaultProps()` method on a
/// UI component class to the Dart 2-compatible alternative of using the
/// `componentDefaultProps` getter on the component's props class.
class ComponentDefaultPropsMigrator implements Suggestor {
  static final RegExp dollarPropsPattern = RegExp(
      // constructor keyword + at least one whitespace char
      r'new\s+'
      // component class name
      // (GROUP 1)
      r'(\w+)Component'
      // parens + optional whitespace
      r'\(\)\s*'
      // getDefaultProps() invocation
      r'\.getDefaultProps\(\)');

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    for (final match in dollarPropsPattern.allMatches(sourceFile.getText(0))) {
      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        '${match.group(1)}().componentDefaultProps',
      );
    }
  }

  @override
  bool shouldSkip(_) => false;
}
