// Copyright 2021 Workiva Inc.
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

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../../util.dart';

String withOverReactAndWsdImports(String source) => /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    import 'package:web_skin_dart/component2/all.dart';
    import 'package:web_skin_dart/component2/all.dart' as wsd_v2;
    import 'package:web_skin_dart/ui_components.dart' as wsd_v1;
    import 'package:web_skin_dart/component2/toolbars.dart' as toolbars_v2;
    import 'package:web_skin_dart/toolbars.dart' as toolbars_v1;
    
    $source
''';

enum SharedHitAreaMixinTests { role, target, type, allowedHandlersWhenDisabled }

/// Tests common assertions shared between WSD components that use `HitAreaMixin`.
void sharedHitAreaMixinTests(
    {@required String? startingFactoryName,
    @required SuggestorTester? testSuggestor,
    String? endingFactoryName,
    String? extraEndingProps,
    List<SharedHitAreaMixinTests> testsToSkip = const []}) {
  if (endingFactoryName == null) {
    endingFactoryName = startingFactoryName;
  }

  if (extraEndingProps == null) {
    extraEndingProps = '';
  }

  if (startingFactoryName == null || testSuggestor == null) {
    throw ArgumentError(
        'startingFactoryName and testSuggestor are required parameters');
  }

  group('(shared `HitAreaMixin` tests)', () {
    if (!testsToSkip.contains(SharedHitAreaMixinTests.role)) {
      test('role', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
              content() {
                ($startingFactoryName()..role = 'foo')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports('''
              content() {
                (mui.$endingFactoryName()..dom.role = 'foo'$extraEndingProps)();
              }
          '''),
        );
      });
    }

    if (!testsToSkip.contains(SharedHitAreaMixinTests.target)) {
      test('target', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
              content() {
                ($startingFactoryName()..target = 'foo')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports('''
              content() {
                (mui.$endingFactoryName()..dom.target = 'foo'$extraEndingProps)();
              }
          '''),
        );
      });
    }

    if (!testsToSkip.contains(SharedHitAreaMixinTests.type)) {
      test('type', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
              content() {
                ($startingFactoryName()..type = 'foo')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports('''
              content() {
                (mui.$endingFactoryName()..dom.type = 'foo'$extraEndingProps)();
              }
          '''),
        );
      });
    }

    if (!testsToSkip
        .contains(SharedHitAreaMixinTests.allowedHandlersWhenDisabled)) {
      test('allowedHandlersWhenDisabled', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..allowedHandlersWhenDisabled = [])();
                }
            '''),
          expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.$endingFactoryName()
                    // FIXME(mui_migration) - allowedHandlersWhenDisabled prop - manually migrate
                    ..allowedHandlersWhenDisabled = []
                  )();
                }
            '''),
        );
      });
    }
  });
}
