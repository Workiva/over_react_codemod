import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../../../util.dart';
import '../shared.dart';

enum HitAreaMixinSkippableTests {
  TYPE,
}

/// Shared tests for components that are migrating a component that mixes in
/// `HitAreaMixin`.
Future<void> sharedHitAreaMixinTests(
    {@required String? startingFactoryName,
    @required SuggestorTester? testSuggestor,
    String? endingFactoryName,
    String? extraEndingProps,
    List<HitAreaMixinSkippableTests> testsToSkip = const []}) async {
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

    if (testsToSkip.contains(HitAreaMixinSkippableTests.TYPE)) {
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
                    ..allowedHandlersWhenDisabled = []$extraEndingProps
                  )();
                }
            '''),
      );
    });

    group(
        'migrates tooltipContent to use a wrapper OverlayTrigger,'
        ' when the prop is', () {
      test('by itself', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
              content() {
                ($startingFactoryName()
                  ..id = ''
                  ..tooltipContent = 'content'
                )();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports('''
              content() {
                (OverlayTrigger()
                  // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                  ..overlay2 = Tooltip()('content')
                )(
                  (mui.$endingFactoryName()..id = ''$extraEndingProps)(),
                );
              }
          '''),
        );
      });

      group('with overlayTriggerProps', () {
        test('as an OverlayTriggerProps map', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..overlayTriggerProps = (OverlayTrigger()
                      ..placement = OverlayPlacement.LEFT
                      ..trigger = OverlayTriggerType.HOVER
                    )
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = Tooltip()('content')
                    ..placement = OverlayPlacement.LEFT
                    ..trigger = OverlayTriggerType.HOVER
                  )(
                    (mui.$endingFactoryName()
                      ..id = ''
                      $extraEndingProps
                    )(),
                  );
                }
            '''),
          );
        });

        test('as an OverlayTriggerProps map (namespaced)', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..overlayTriggerProps = (wsd_v2.OverlayTrigger()
                      ..placement = OverlayPlacement.LEFT
                      ..trigger = OverlayTriggerType.HOVER
                    )
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = Tooltip()('content')
                    ..placement = OverlayPlacement.LEFT
                    ..trigger = OverlayTriggerType.HOVER
                  )(
                    (mui.$endingFactoryName()..id = ''$extraEndingProps)(),
                  );
                }
            '''),
          );
        });

        test('as another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content(Function getProps) {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..overlayTriggerProps = getProps()
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content(Function getProps) {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = Tooltip()('content')
                    ..addProps(getProps())
                  )(
                    (mui.$endingFactoryName()..id = ''$extraEndingProps)(),
                  );
                }
            '''),
          );
        });
      });

      group('with tooltipProps', () {
        test('as a TooltipProps map', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..tooltipProps = (Tooltip()
                      ..className = 'my-tooltip'
                    )
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = (Tooltip()
                      ..className = 'my-tooltip'
                    )('content')
                  )(
                    (mui.$endingFactoryName()
                      ..id = ''
                      $extraEndingProps
                    )(),
                  );
                }
            '''),
          );
        });

        test('as a TooltipProps map (namespaced)', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..tooltipProps = (wsd_v2.Tooltip()
                      ..className = 'my-tooltip'
                    )
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = (Tooltip()
                      ..className = 'my-tooltip'
                    )('content')
                  )(
                    (mui.$endingFactoryName()
                      ..id = ''
                      $extraEndingProps
                    )(),
                  );
                }
            '''),
          );
        });

        test('as another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content(Function getProps) {
                  ($startingFactoryName()
                    ..tooltipContent = 'content'
                    ..tooltipProps = getProps()
                    ..id = ''
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content(Function getProps) {
                  (OverlayTrigger()
                    // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                    ..overlay2 = (Tooltip()
                      ..addProps(getProps())
                    )('content')
                  )(
                    (mui.$endingFactoryName()..id = ''$extraEndingProps)(),
                  );
                }
            '''),
          );
        });
      });

      test('with overlayTriggerProps and tooltipProps', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
              content() {
                ($startingFactoryName()
                  ..tooltipContent = 'content'
                  ..overlayTriggerProps = (OverlayTrigger()
                    ..placement = OverlayPlacement.LEFT
                    ..trigger = OverlayTriggerType.HOVER
                  )
                  ..tooltipProps = (Tooltip()..className = 'my-tooltip')
                  ..id = ''
                )();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports('''
              content() {
                (OverlayTrigger()
                  // FIXME(mui_migration) - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger
                  ..overlay2 = (Tooltip()..className = 'my-tooltip')('content')
                  ..placement = OverlayPlacement.LEFT
                  ..trigger = OverlayTriggerType.HOVER
                )(
                  (mui.$endingFactoryName()
                    ..id = ''
                    $extraEndingProps
                  )(),
                );
              }
          '''),
        );
      });
    });
  });
}
