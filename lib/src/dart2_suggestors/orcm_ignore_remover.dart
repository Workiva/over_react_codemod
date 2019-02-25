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

/// Suggestor that removes every instance of a `// orcm_ignore` comment.
class OrcmIgnoreRemover implements Suggestor {
  final _orcmIgnore = RegExp(r'[\n]?[ ]*//[ ]*orcm_ignore[ ]*');

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    for (final match in _orcmIgnore.allMatches(sourceFile.getText(0))) {
      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        '',
      );
    }
  }

  @override
  bool shouldSkip(_) => false;
}
