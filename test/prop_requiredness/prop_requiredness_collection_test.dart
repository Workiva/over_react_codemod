import 'dart:convert';
import 'dart:io';

import 'package:over_react_codemod/src/prop_requiredness/aggregated_data.sg.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

main() {
  group('prop requiredness data collection', () {
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

      test('for set rate (private props)', () {});
    });
    // Use a longer timeout since setupAll can be slow.
  }, timeout: Timeout(Duration(seconds: 60)));
}

Future<PropRequirednessResults> collectAndAggregateDataForTestPackage() async {
  print('Collecting data (this may take a while)...');
  final tmpFolder =
      Directory.systemTemp.createTempSync('prop-requiredness-test');

  final orcmRoot = findPackageRootFor(p.current);
  final testPackagePath =
      p.join(orcmRoot, 'test/test_fixtures/required_props/test_package');

  final collectOutputDirectory = Directory(p.join(tmpFolder.path, 'collected'));

  await runCommandAndThrowIfFailedInheritIo('dart', [
    'run',
    p.join(orcmRoot, 'bin/prop_requiredness/collect.dart'),
    ...['--output-directory', collectOutputDirectory.path],
    testPackagePath,
  ]);

  final collectOutputFile = collectOutputDirectory
      .listSync()
      .cast<File>()
      .where((f) => p.extension(f.path) == '.json')
      .single;

  print('Aggregating data...');

  final aggregateOutputFile = File(p.join(tmpFolder.path, 'aggregated.json'));
  await runCommandAndThrowIfFailedInheritIo('dart', [
    'run',
    p.join(orcmRoot, 'bin/prop_requiredness/aggregate.dart'),
    ...['--output', aggregateOutputFile.path],
    collectOutputFile.path,
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
