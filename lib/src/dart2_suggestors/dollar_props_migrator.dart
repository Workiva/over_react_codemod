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
  r'(?:const|new)\s+'
  // optional over_react import prefix + optional whitespace
  r'(?:\w+\s*\.\s*)?'
  // $Props constructor + optional whitespace
  r'\$Props\s*'
  // opening paren + optional whitespace
  r'\(\s*'
  // props arg, including optional import prefix
  // (GROUP 2)
  r'([\w$.]+)'
  // optional whitespace + optional trailing comma + optional whitespace
  r'\s*(?:,)?\s*'
  // closing paren
  r'\)',
);

/// Suggestor that migrates usages of `$Props()` to the Dart 2-compatible
/// alternative of accessing the props list off of the static `meta` field on
/// the props class.
Stream<Patch> dollarPropsMigrator(FileContext context) async* {
  for (final match in dollarPropsPattern.allMatches(context.sourceText)) {
    yield Patch(
      '${match.group(1)}.meta',
      match.start,
      match.end,
    );
  }
}
