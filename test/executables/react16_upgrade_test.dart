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

import '../dart_project_faker.dart';

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

final tansitionPubspecFaker = PubspecFaker(
    dependencies: [DependencyFaker('react', version: '">=4.0.0 <6.0.0"')]);

final versionChecksToTest = [
  // Codemod comment validation
  DartProjectFakerTestConfig(
      testName: 'exits with status code 1 when there is an unaddressed comment',
      mainDartContents: unaddressedComment,
      dependencies: tansitionPubspecFaker.dependencies,
      expectedExitCode: 1),
  DartProjectFakerTestConfig(
      testName: 'exits with status code 0 when there is no comment',
      mainDartContents: noComment,
      dependencies: tansitionPubspecFaker.dependencies,
      expectedExitCode: 0),
  DartProjectFakerTestConfig(
      testName: 'exits with status code 0 when there is a validated comment',
      mainDartContents: validatedComment,
      dependencies: tansitionPubspecFaker.dependencies,
      expectedExitCode: 0),

  // Pubspec checks
  DartProjectFakerTestConfig(
    testName:
        'does not run the codemod when project does not have a pubspec.yaml or if it is no parsable',
    includePubspecFile: false,
    shouldRunCodemod: false,
  ),

  DartProjectFakerTestConfig(
    testName:
        'does not run the codemod when project does not have react or over_react as dependencies',
    dependencies: [],
    shouldRunCodemod: false,
  ),

  // React-dart version tests
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(reactPackageName, version: 'any')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(reactPackageName, version: '^4.0.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(reactPackageName, version: '^4.1.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(dependencies: [
    DependencyFaker(reactPackageName, version: '">=4.0.0 <6.0.0"')
  ], shouldRunCodemod: true),
  DartProjectFakerTestConfig(dependencies: [
    DependencyFaker(reactPackageName, version: '">=4.1.0 <6.0.0"')
  ], shouldRunCodemod: true),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(reactPackageName, version: '^5.0.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(reactPackageName, version: '^5.1.0')],
      shouldRunCodemod: false),

  // OverReact version tests
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(overReactPackageName, version: 'any')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(overReactPackageName, version: '^2.0.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(overReactPackageName, version: '^2.1.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(dependencies: [
    DependencyFaker(overReactPackageName, version: '">=2.0.0 <4.0.0"')
  ], shouldRunCodemod: true),
  DartProjectFakerTestConfig(dependencies: [
    DependencyFaker(overReactPackageName, version: '">=2.1.0 <4.0.0"')
  ], shouldRunCodemod: true),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(overReactPackageName, version: '^3.0.0')],
      shouldRunCodemod: false),
  DartProjectFakerTestConfig(
      dependencies: [DependencyFaker(overReactPackageName, version: '^3.1.0')],
      shouldRunCodemod: false),

  // Edge Cases
  DartProjectFakerTestConfig(
    testName:
        'runs the codemod when project has both react & over_react in transition',
    dependencies: [
      DependencyFaker(overReactPackageName, version: '">=2.0.0 <4.0.0"'),
      DependencyFaker(reactPackageName, version: '">=4.0.0 <6.0.0"'),
    ],
    shouldRunCodemod: true,
  ),

  DartProjectFakerTestConfig(
    testName:
        'does not run the codemod when project has both react & over_react but over_react is not in transition',
    dependencies: [
      DependencyFaker(overReactPackageName, version: '^2.0.0'),
      DependencyFaker(reactPackageName, version: '">=4.0.0 <6.0.0"'),
    ],
    shouldRunCodemod: false,
  ),

  DartProjectFakerTestConfig(
    testName:
        'does not run the codemod when project has both react & over_react but react is not in transition',
    dependencies: [
      DependencyFaker(overReactPackageName, version: '">=2.0.0 <4.0.0"'),
      DependencyFaker(reactPackageName, version: '^4.0.0'),
    ],
    shouldRunCodemod: false,
  ),
];

ProcessResult runUpgrade({String onDirectory}) {
  // This command is equivalent to `pub run over_react_codemod:react16_upgrade`
  // but allows us to not need to run pub get on each of these fake packages because over_react/react.dart have not been
  // released yet these tests will fail a pub get
  var result = Process.runSync(
    'dart',
    [
      '--enable-asserts',
      p.join(Directory.current.path, 'bin/react16_upgrade.dart')
    ],
    workingDirectory: onDirectory,
  );
  // Show output from command
  print(result.stdout);
  return result;
}

ProcessResult runUpgradeWithFakeDartProject(
    {PubspecFaker pubspecFaker, String mainDartContents}) {
  var testPackage = DartProjectFaker(
      pubspecFaker: pubspecFaker ?? tansitionPubspecFaker,
      mainDartContents: mainDartContents);
  return runUpgrade(onDirectory: testPackage.dir.path);
}

main() {
  group('React16_upgrade', () {
    for (var dartProjectTestConfig in versionChecksToTest) {
      test(dartProjectTestConfig.testName, () {
        final result = runUpgradeWithFakeDartProject(
          pubspecFaker: PubspecFaker(
              dependencies: dartProjectTestConfig.dependencies,
              createPubspecFile: dartProjectTestConfig.includePubspecFile),
          mainDartContents:
              dartProjectTestConfig.mainDartContents ?? unaddressedComment,
        );
        expect(result.exitCode, dartProjectTestConfig.expectedExitCode,
            reason: result.stderr);
      });
    }
  });
}
