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

@TestOn('vm')
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/dart2_suggestors/orcm_ignore_remover.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('Dart2 migration suggestors', () {
    final suggestorMap = <String, Suggestor>{
      'OrcmIgnoreRemover': orcmIgnoreRemover,
    };
    testSuggestorsDir(suggestorMap, 'test/dart2_suggestors');
  });
}
