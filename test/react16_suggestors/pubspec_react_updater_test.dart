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

import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../shared_pubspec_test.dart';
import '../util.dart';

main() {
  group('PubspecReactUpdater', () {
    final testSuggestor = getSuggestorTester(
        PubspecReactUpdater(VersionConstraint.parse(reactVersionRange)));

    sharedPubspecTest(
        testSuggestor: testSuggestor,
        getExpectedOutput: getExpectedOutput,
        startingRange: VersionConstraint.parse('>=4.6.1 <4.6.5'),
        dependency: 'react',
        shouldUpdateMidRange: true,
        midVersionRange: '^4.6.3');
  });
}

String getExpectedOutput({
  bool shouldAddSpace = false,
  bool usesDoubleQuotes = false,
}) {
  String quotes = usesDoubleQuotes ? '"' : "'";

  return ''
      '${shouldAddSpace ? '  ' : ''}react: $quotes>=4.7.0 <6.0.0$quotes\n'
      '${shouldAddSpace ? '  ' : ''}test: 1.5.1\n'
      '';
}
