// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:over_react_codemod/src/creator_utils.dart';

final String unaddressedComment = 'void main() {\n'
    '  // [ ] Check this box upon manual validation that the component rendered by this expression uses a ref safely. '
    'This will be removed once the transition to React 16 is complete.\n'
    '}\n';
final String noComment = 'void main() {}';
final String validatedComment = 'void main() {\n'
    '  // [x] Check this box upon manual validation\n'
    '}\n';

final reactPackageName = 'react';
final overReactPackageName = 'over_react';

final tansitionPubspecCreator = PubspecCreator(
    dependencies: [DependencyCreator('react', version: '">=4.0.0 <6.0.0"')]);

final versionChecksToTest = [
  DartProjectCreatorTestConfig(
      testName: 'exits with status code 1 when there is an unaddressed comment',
      mainDartContents: unaddressedComment,
      dependencies: tansitionPubspecCreator.dependencies,
      expectedExitCode: 1),
  DartProjectCreatorTestConfig(
      testName: 'exits with status code 0 when there is no comment',
      mainDartContents: noComment,
      dependencies: tansitionPubspecCreator.dependencies,
      expectedExitCode: 0),
  DartProjectCreatorTestConfig(
      testName: 'exits with status code 0 when there is a validated comment',
      mainDartContents: validatedComment,
      dependencies: tansitionPubspecCreator.dependencies,
      expectedExitCode: 0),
];

ProcessResult runUpgrade({String onDirectory}) {
  // This command is equivalent to `pub global run over_react_codemod:react16_upgrade`
  // but allows us to not need to run pub get on each of these fake packages because over_react/react.dart have not been
  // released yet these tests will fail a pub get
  var result = Process.runSync(
    'dart',
    [
      '--enable-asserts',
      p.join(Directory.current.path, 'bin/react16_upgrade.dart'),
      '--yes-to-all'
    ],
    workingDirectory: onDirectory,
  );
  // Show output from command
  print(result.stdout);
  return result;
}

main() {
  group('React16_upgrade', () {
    for (var dartProjectTestConfig in versionChecksToTest) {
      test(dartProjectTestConfig.testName, () {
        final testPackage = DartTempProjectCreator(
            pubspecCreators: dartProjectTestConfig.pubspecCreators,
            mainDartContents:
                dartProjectTestConfig.mainDartContents ?? unaddressedComment);
        final result = runUpgrade(onDirectory: testPackage.dir.path);
        expect(result.exitCode, dartProjectTestConfig.expectedExitCode,
            reason: result.stderr);
      });
    }
  });
}
