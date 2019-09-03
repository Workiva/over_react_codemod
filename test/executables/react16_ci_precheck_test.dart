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

final reactPackageName = 'react';
final overReactPackageName = 'over_react';

final tansitionPubspecCreator = PubspecCreator(
    dependencies: [DependencyCreator('react', version: '">=4.0.0 <6.0.0"')]);

final versionChecksToTest = [
  // Pubspec checks
  DartProjectCreatorTestConfig(
    testName:
        'returns status code 0 when project does not have a pubspec.yaml or if it is no parsable',
    includePubspecFile: false,
    expectedExitCode: 0,
  ),

  DartProjectCreatorTestConfig(
    testName:
        'returns status code 0 when project does not have react or over_react as dependencies',
    dependencies: [],
    expectedExitCode: 0,
  ),

  // React-dart version tests
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(reactPackageName, version: 'any')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(reactPackageName, version: '^4.0.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(reactPackageName, version: '^4.1.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [
      DependencyCreator(reactPackageName, version: '">=4.0.0 <6.0.0"')
    ],
    expectedExitCode: 1,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [
      DependencyCreator(reactPackageName, version: '">=4.1.0 <6.0.0"')
    ],
    expectedExitCode: 1,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(reactPackageName, version: '^5.0.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(reactPackageName, version: '^5.1.0')],
    expectedExitCode: 0,
  ),

  // OverReact version tests
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(overReactPackageName, version: 'any')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(overReactPackageName, version: '^2.0.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(overReactPackageName, version: '^2.1.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [
      DependencyCreator(overReactPackageName, version: '">=2.0.0 <4.0.0"')
    ],
    expectedExitCode: 1,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [
      DependencyCreator(overReactPackageName, version: '">=2.1.0 <4.0.0"')
    ],
    expectedExitCode: 1,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(overReactPackageName, version: '^3.0.0')],
    expectedExitCode: 0,
  ),
  DartProjectCreatorTestConfig(
    dependencies: [DependencyCreator(overReactPackageName, version: '^3.1.0')],
    expectedExitCode: 0,
  ),

  // Edge Cases
  DartProjectCreatorTestConfig(
    testName:
        'runs the codemod when project has both react & over_react in transition',
    dependencies: [
      DependencyCreator(overReactPackageName, version: '">=2.0.0 <4.0.0"'),
      DependencyCreator(reactPackageName, version: '">=4.0.0 <6.0.0"'),
    ],
    expectedExitCode: 1,
  ),

  DartProjectCreatorTestConfig(
    testName:
        'does not run the codemod when project has both react & over_react but over_react is not in transition',
    dependencies: [
      DependencyCreator(overReactPackageName, version: '^2.0.0'),
      DependencyCreator(reactPackageName, version: '">=4.0.0 <6.0.0"'),
    ],
    expectedExitCode: 0,
  ),

  DartProjectCreatorTestConfig(
    testName:
        'does not run the codemod when project has both react & over_react but react is not in transition',
    dependencies: [
      DependencyCreator(overReactPackageName, version: '">=2.0.0 <4.0.0"'),
      DependencyCreator(reactPackageName, version: '^4.0.0'),
    ],
    expectedExitCode: 0,
  ),
];

ProcessResult runCiPrecheck({String onDirectory}) {
  // This command is equivalent to `pub run over_react_codemod:react16_upgrade`
  // but allows us to not need to run pub get on each of these fake packages because over_react/react.dart have not been
  // released yet these tests will fail a pub get
  var result = Process.runSync(
    'dart',
    [
      '--enable-asserts',
      p.join(Directory.current.path, 'bin/react16_ci_precheck.dart')
    ],
    workingDirectory: onDirectory,
  );
  // Show output from command
  print(result.stdout);
  return result;
}

ProcessResult runCiPrecheckWithFakeDartProject(
    {PubspecCreator pubspecCreator, String mainDartContents}) {
  var testPackage = DartTempProjectCreator(
      pubspecCreator: pubspecCreator ?? tansitionPubspecCreator,
      mainDartContents: mainDartContents);
  return runCiPrecheck(onDirectory: testPackage.dir.path);
}

main() {
  group('React16_ci_precheck', () {
    for (var dartProjectTestConfig in versionChecksToTest) {
      test(dartProjectTestConfig.testName, () {
        final result = runCiPrecheckWithFakeDartProject(
          pubspecCreator: PubspecCreator(
              dependencies: dartProjectTestConfig.dependencies,
              createPubspecFile: dartProjectTestConfig.includePubspecFile),
        );
        expect(result.exitCode, dartProjectTestConfig.expectedExitCode,
            reason: result.stderr);
      });
    }
  });
}
