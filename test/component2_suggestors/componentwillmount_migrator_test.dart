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

import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ComponentWillMountMigrator', () {
    final testSuggestor = getSuggestorTester(ComponentWillMountMigrator());

    test('empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
      );
    });

    test('componentWillMount method updates', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
              componentWillMount(){
                  // method body
              }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
              init(){
                  // method body
              }
          }
        ''',
      );
    });

    test('componentWillMount method with return type updates', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          import 'package:react/react.dart' as react;
          
          @Component2()
          class FooComponent extends react.Component2 {
              void componentWillMount(){
                  // method body
              }
          }
        ''',
        expectedOutput: '''
          import 'package:react/react.dart' as react;
          
          @Component2()
          class FooComponent extends react.Component2 {
              void init(){
                  // method body
              }
          }
        ''',
      );
    });

    group('remove super calls to componentWillMount', () {
      test('for UiComponent2 extending class', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
              void componentWillMount(){
                  super.componentWillMount();
                  // method body
              }
          }
        ''',
          expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
              void init(){
                  // method body
              }
          }
        ''',
        );
      });

      test('for UiStatefulComponent2 extending class', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2 {
              void componentWillMount(){
                  super.componentWillMount();
                  // method body
              }
          }
        ''',
          expectedOutput: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2 {
              void init(){
                  // method body
              }
          }
        ''',
        );
      });

      test('for react.Component2 extending class', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
          import 'package:react/react.dart' as react;
          
          @Component2()
          class FooComponent extends react.Component2 {
              void componentWillMount(){
                  super.componentWillMount();
                  // method body
              }
          }
        ''',
          expectedOutput: '''
          import 'package:react/react.dart' as react;
          
          @Component2()
          class FooComponent extends react.Component2 {
              void init(){
                  // method body
              }
          }
        ''',
        );
      });
    });

    test(
        'do not remove super calls to componentWillMount for non-base extending classes',
        () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
              void componentWillMount(){
                  super.componentWillMount();
                  // method body
              }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
              void init(){
                  super.componentWillMount();
                  // method body
              }
          }
        ''',
      );
    });

    test('does not change componentWillMount for non-component2 classes', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component()
          class FooComponent extends UiComponent {
              void componentWillMount(){
                  // method body
              }
          }
        ''',
      );
    });
  });
}
