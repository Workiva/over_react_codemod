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

import 'package:over_react_codemod/src/react16_suggestors/consumer_overlay_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ConsumerOverlayMigrator', () {
    final testSuggestor = getSuggestorTester(ConsumerOverlayMigrator());

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

    test('`overlay` prop', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return (OverlayTrigger()
                ..overlay = _renderIndicator()
              )(_renderMainContent());
            }
          }
        ''',
        expectedOutput: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return (OverlayTrigger()
                ..overlay2 = _renderIndicator()
              )(_renderMainContent());
            }
          }
        ''',
      );
    });

    test('`isOverlay` prop', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay = false
              ..initiallyOpen = false
            );
          }
        ''',
        expectedOutput: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay2 = false
              ..initiallyOpen = false
            );
          }
        ''',
      );
    });

    test('`useLegacyPositioning` prop', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..useLegacyPositioning = false
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
        expectedOutput: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
      );
    });

    test('`overlay`, `isOverlay`, and `useLegacyPositioning` props', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          @Component()
          class FooComponent extends SomeOtherClass<FooProps> {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay = false
              ..initiallyOpen = false
            );
            
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..trigger = OverlayTriggerType.MANUAL
                ..useLegacyPositioning = false
                ..overlay = _renderIndicator()
                ..repositionOverlay = repositionOverlayOverTrigger
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
        expectedOutput: '''
          @Component()
          class FooComponent extends SomeOtherClass<FooProps> {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay2 = false
              ..initiallyOpen = false
            );
            
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..trigger = OverlayTriggerType.MANUAL
                ..overlay2 = _renderIndicator()
                ..repositionOverlay = repositionOverlayOverTrigger
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
      );
    });

    test('already updated props', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component()
          class FooComponent extends SomeOtherClass<FooProps> {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay2 = false
              ..initiallyOpen = false
            );
            
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..trigger = OverlayTriggerType.MANUAL
                ..overlay2 = _renderIndicator()
                ..repositionOverlay = repositionOverlayOverTrigger
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
      );
    });

    test('props outside of component class', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          class FooClass extends SomeOtherClass {
            @override
            Map getDefaultProps() => (newProps()
              ..isFontSizeControl = false
              ..isOverlay = false
              ..initiallyOpen = false
            );
            
            @override
            render() {
              return (OverlayTrigger()
                ..addProps(props.overlayTriggerProps)
                ..trigger = OverlayTriggerType.MANUAL
                ..useLegacyPositioning = false
                ..overlay = _renderIndicator()
                ..repositionOverlay = repositionOverlayOverTrigger
                ..ref = ((ref) => overlayTriggerRef = ref)
              )(_renderMainContent());
            }
          }
        ''',
      );
    });
  });
}
