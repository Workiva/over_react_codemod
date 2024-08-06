// Copyright 2024 Workiva Inc.
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

import 'dart:convert';
import 'dart:io';

import 'package:over_react_codemod/src/dart3_suggestors/required_props/collect/aggregated_data.sg.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

main() {
  group('null_safety_required_props collect command', () {
    late PropRequirednessResults aggregated;

    setUpAll(() async {
      // Use this instead for local dev if you want to run collection manually
      // as opposed to on every test run.
      // final localDevAggregatedOutputFile = 'prop_requiredness.json';
      // aggregated = PropRequirednessResults.fromJson(
      //     jsonDecode(File(localDevAggregatedOutputFile).readAsStringSync()));
      aggregated = await collectAndAggregateDataForTestPackage();
    });

    group('collects expected data', () {
      test('for visibility of props mixins', () {
        const expectedVisibilities = {
          'TestPrivateProps': Visibility.private,
          'TestPublicProps': Visibility.public,
          'TestFactoryOnlyExportedProps': Visibility.indirectlyPublic,
        };
        final actualVisibiilities = {
          for (final name in expectedVisibilities.keys)
            name: aggregated.mixinResultsByName(name).visibility
        };
        expect(actualVisibiilities, expectedVisibilities);
      });

      group('for private props used within their own package:', () {
        test('set rate', () {
          final mixinResults =
              aggregated.mixinResultsByName('TestPrivateProps');
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.samePackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 0.8),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.totalRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 0.8),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.otherPackageRate),
            allOf(
              containsPair('set100percent', null),
              containsPair('set80percent', null),
              containsPair('set20percent', null),
            ),
            reason:
                'props only used in the same package should not have otherPackageRate populated',
          );

          expect(mixinResults.usageSkipRate, 0);
        });

        test('set rate when used by multiple components', () {
          final mixinResults = aggregated
              .mixinResultsByName('TestPrivateUsedByMultipleComponentsProps');
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.samePackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 0.8),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.totalRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 0.8),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.otherPackageRate),
            allOf(
              containsPair('set100percent', null),
              containsPair('set80percent', null),
              containsPair('set20percent', null),
            ),
            reason:
                'props only used in the same package should not have otherPackageRate populated',
          );

          expect(mixinResults.usageSkipRate, 0);
        });

        group('skip rate:', () {
          test('props that are never skipped', () {
            final mixinResults =
                aggregated.mixinResultsByName('TestPrivateProps');
            expect(mixinResults.usageSkipRate, 0);
            expect(mixinResults.usageSkipCount, 0);
          });

          group('props that are skipped due to', () {
            test('dynamic prop additions', () {
              expect(aggregated.excludeOtherDynamicUsages, isTrue,
                  reason: 'test setup check');

              final mixinResults =
                  aggregated.mixinResultsByName('TestPrivateDynamicProps');
              const expectedSkipCount = 3;
              const expectedTotalUsages = 4;
              expect(mixinResults.usageSkipCount, expectedSkipCount);
              expect(mixinResults.usageSkipRate,
                  expectedSkipCount / expectedTotalUsages);
            });

            test('forwarded props', () {
              expect(aggregated.excludeUsagesWithForwarded, isTrue,
                  reason: 'test setup check');

              final mixinResults =
                  aggregated.mixinResultsByName('TestPrivateForwardedProps');
              const expectedSkipCount = 5;
              const expectedTotalUsages = 6;
              expect(mixinResults.usageSkipCount, expectedSkipCount);
              expect(mixinResults.usageSkipRate,
                  expectedSkipCount / expectedTotalUsages);
            });
          });
        });
      });

      group('for public props used in multiple packages:', () {
        test('set rate', () {
          final mixinResults = aggregated.mixinResultsByName('TestPublicProps');
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.totalRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.samePackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set20percent', anyOf(null, 0.0)),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.otherPackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set20percent', 1.0),
            ),
          );

          expect(mixinResults.usageSkipRate, 0);
        });

        test('set rate when used by multiple components', () {
          final mixinResults = aggregated
              .mixinResultsByName('TestPublicUsedByMultipleComponentsProps');

          expect(
            mixinResults.propResultsByName.mapValues((v) => v.totalRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 0.8),
              containsPair('set20percent', 0.2),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.samePackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 1.0),
              containsPair('set20percent', 0.5),
            ),
          );
          expect(
            mixinResults.propResultsByName.mapValues((v) => v.otherPackageRate),
            allOf(
              containsPair('set100percent', 1.0),
              containsPair('set80percent', 2 / 3),
              containsPair('set20percent', anyOf(null, 0.0)),
            ),
          );
          expect(mixinResults.usageSkipRate, 0);
        });

        group('skip rate:', () {
          test('props that are never skipped', () {
            final mixinResults =
                aggregated.mixinResultsByName('TestPublicProps');
            expect(mixinResults.usageSkipRate, 0);
            expect(mixinResults.usageSkipCount, 0);
          });
        });
      });

      test('does not aggregate data for non-factory usages', () {
        final mixinResults =
            aggregated.mixinResultsByName('TestPrivateNonFactoryUsagesProps');
        final propTotalRates =
            mixinResults.propResultsByName.mapValues((v) => v.totalRate);
        expect(
          mixinResults.propResultsByName['set100percent'],
          isA<PropResult>()
              .having((r) => r.totalRate, 'totalRate', 1)
              .having((r) => r.totalUsageCount, 'totalUsageCount', 1),
          reason:
              'test setup check: should contain data for the single factory-based usage',
        );
        expect(propTotalRates.keys.toList(), unorderedEquals(['set100percent']),
            reason:
                'should not contain data for non-factory usages and props set on them, such as `onlySetOnNonFactoryUsages`');
      });
    });
    // Use a longer timeout since setupAll can be slow.
  }, timeout: Timeout(Duration(seconds: 60)));
}

Future<PropRequirednessResults> collectAndAggregateDataForTestPackage() async {
  print('Collecting data (this may take a while)...');
  final tmpFolder =
      Directory.systemTemp.createTempSync('prop-requiredness-test');
  addTearDown(() => tmpFolder.delete(recursive: true));

  final orcmRoot = findPackageRootFor(p.current);
  final testPackagePath = p.join(
      orcmRoot, 'test/test_fixtures/required_props/test_consuming_package');

  final aggregateOutputFile = File(p.join(tmpFolder.path, 'aggregated.json'));

  await runCommandAndThrowIfFailedInheritIo('dart', [
    'run',
    p.join(orcmRoot, 'bin/null_safety_required_props.dart'),
    'collect',
    ...['--output', aggregateOutputFile.path],
    testPackagePath,
  ]);

  return PropRequirednessResults.fromJson(
      jsonDecode(aggregateOutputFile.readAsStringSync()));
}

extension on PropRequirednessResults {
  static const testPackageName = 'test_package';

  String mixinIdForName(String mixinName) {
    return mixinMetadata.mixinNamesById.entries
        .singleWhere((entry) => entry.value == mixinName)
        .key;
  }

  MixinResult mixinResultsByName(String mixinName) {
    final mixinId = mixinIdForName(mixinName);
    return this.mixinResultsByIdByPackage[testPackageName]![mixinId]!;
  }
}

extension<K, V> on Map<K, V> {
  /// Returns a new map with values transformed by [convertValue].
  Map<K, T> mapValues<T>(T convertValue(V value)) =>
      map((key, value) => MapEntry(key, convertValue(value)));
}
