import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/prop_requiredness/aggregated_data.sg.dart';
import 'package:over_react_codemod/src/prop_requiredness/collected_data.sg.dart';
import 'package:over_react_codemod/src/prop_requiredness/logging.dart';

Future<void> main(List<String> args) async {
  final argParser = ArgParser()
    ..addFlag('help', help: 'Print this usage information', negatable: false)
    ..addOption(
      'output',
      abbr: 'o',
      help: 'The file to write output to.',
      valueHelp: 'path',
      defaultsTo: 'prop_requiredness.json',
    );
  final parsedArgs = argParser.parse(args);
  if (parsedArgs['help'] as bool) {
    print(argParser.usage);
    exit(ExitCode.success.code);
  }
  final outputFile = parsedArgs['output']!;
  final filesToAggregate = parsedArgs.rest;
  if (filesToAggregate.isEmpty) {
    print('Must specify files to aggregate.\n${argParser.usage}');
    exit(ExitCode.usage.code);
  }

  initLogging();
  final logger = Logger('prop_requiredness_aggregate');

  logger.info('Loading results from files specified in arguments...');
  final allResults = filesToAggregate.map(File.new).map((file) {
    final results = tryParseResults(file.readAsStringSync());
    if (results == null)
      throw Exception('Error parsing results for $file; is version outdated?');
    if (results.dataVersion != PackageResults.latestDataVersion) {
      throw Exception('Outdated data version in $file');
    }
    return results;
  }).toList();

  {
    // Gather some stats on how often different builder types show up.
    final allUsages = allResults.expand((r) => r.usages);

    final countsByBuilderType =
        allUsages.countBy((u) => u.usageBuilderType.name);
    File('counts_by_builder_type.json')
        .writeAsStringSync(jsonEncodeIndented(countsByBuilderType));

    final countsByBuilderTypeByMixin = allUsages
        .multiGroupListsBy((u) => u.mixinData.map((e) => e.mixinId))
        .map((mixinId, usages) =>
            MapEntry(mixinId, usages.countBy((u) => u.usageBuilderType.name)));
    File('counts_by_builder_type_by_mixin.json')
        .writeAsStringSync(jsonEncodeIndented(countsByBuilderTypeByMixin));
  }

  logger.info('Aggregating data...');
  final aggregated = aggregateData(allResults);
  logger.info('Done.');

  // logger.fine('Props mixins with the same name:');
  // final mixinIdsByName = aggregated.mixinMetadata.mixinNamesById.keysByValues();
  // mixinIdsByName.forEach((name, mixinIds) {
  //   if (mixinIds.length > 1) logger.fine('$name: ${mixinIds.map((id) => '\n - $id').join('')}');
  // });

  File(outputFile).writeAsStringSync(jsonEncodeIndented(aggregated));
  logger.info('Wrote JSON results to $outputFile');
}

final jsonEncodeIndented = const JsonEncoder.withIndent('  ').convert;

extension<E> on Iterable<E> {
  Map<T, int> countBy<T>(T Function(E) getBucket) {
    final counts = <T, int>{};
    for (final element in this) {
      final bucket = getBucket(element);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts;
  }

  /// Like [groupListsBy] but allows elements to be added to multiple groups.
  Map<T, List<E>> multiGroupListsBy<T>(Iterable<T> Function(E) keysOf) {
    final groups = <T, List<E>>{};
    for (final element in this) {
      for (final key in keysOf(element)) {
        groups.putIfAbsent(key, () => []).add(element);
      }
    }
    return groups;
  }
}

PropRequirednessResults aggregateData(
  List<PackageResults> allResults, {
  bool excludeOtherDynamicUsages = true,
  bool excludeUsagesWithForwarded = true,
  bool topLevelFactoryUsagesOnly = true,
  bool outputDebugData = true,
}) {
  final logger = Logger('aggregateData');

  logger.finer('Checking for duplicates...');
  // Validate that there are no duplicates in the data set
  {
    final resultsByPackageName = <String, Set<PackageResults>>{};
    for (final result in allResults) {
      for (final packageName in [
        result.packageName,
        ...result.otherPackageNames
      ]) {
        resultsByPackageName.putIfAbsent(packageName, () => {}).add(result);
      }
    }
    var duplicateResultsMessages = <String>[];
    resultsByPackageName.forEach((packageName, results) {
      if (results.length != 1) {
        duplicateResultsMessages.add(
            'Results for package $packageName were found in more than one results set:'
            ' ${results.map((r) => 'PackageResults(packageName:$packageName)').toList()}');
      }
    });
    if (duplicateResultsMessages.isNotEmpty) {
      throw Exception(
          'Duplicate results:\n${duplicateResultsMessages.join('\n')}');
    }
  }

  final mixinIdsByVisibilityByPackage = {
    for (final result in allResults) ...result.mixinIdsByVisibilityByPackage,
  };

  final mismatchedMixinIdsByUsagePackage = <String, Set<String>>{};
  for (final result in allResults) {
    for (final usage in result.usages) {
      final usagePackage = usage.usagePackage;
      for (final mixinData in usage.mixinData) {
        final mixinPackage = mixinData.mixinPackage;
        if (mixinPackage != usagePackage) {
          final mixinId = mixinData.mixinId;
          final mixinName = mixinData.mixinName;
          final mixinIdsByVisibility =
              mixinIdsByVisibilityByPackage[mixinPackage];
          if (mixinIdsByVisibility != null &&
              getVisibilityForMixinIdOrCompanion(mixinIdsByVisibility,
                      mixinId: mixinId, mixinName: mixinName) !=
                  null) {
            mismatchedMixinIdsByUsagePackage
                .putIfAbsent(usagePackage, () => {})
                .add(mixinId);
          }
        }
      }
    }
  }

  if (mismatchedMixinIdsByUsagePackage.isNotEmpty) {
    logger.warning(
        "Found usages of mixins in other packages that don't have declaration data:"
        " ${mismatchedMixinIdsByUsagePackage.keys.toList()}");
    mismatchedMixinIdsByUsagePackage.forEach((packageName, mixinIds) {
      logger.warning(
          "- $packageName:\n${mixinIds.map((i) => '  - $i').join('\n')}");
    });
  }

  final usageStatsByMixinId = <String, CategorizedPropsMixinUsageStats>{};
  final allMixinIds = <String>{};

  final mixinNamesById = <String, String>{};
  final mixinPackagesById = <String, String>{};

  UsageSkipReason? getUsageSkipReason(Usage usage) {
    if (topLevelFactoryUsagesOnly &&
        usage.usageBuilderType != BuilderType.topLevelFactory) {
      return UsageSkipReason.nonTopLevelFactory;
    }
    if (excludeUsagesWithForwarded && usage.usageHasForwardedProps) {
      return UsageSkipReason.hasForwardedProps;
    }
    if (excludeOtherDynamicUsages && usage.usageHasOtherDynamicProps) {
      return UsageSkipReason.hasOtherDynamicProps;
    }
    return null;
  }

  final allUsages = allResults.expand((r) => r.usages);

  logger.finer('Tallying usages...');
  for (final usage in allUsages) {
    final skipReason = getUsageSkipReason(usage);

    for (final mixin in usage.mixinData) {
      allMixinIds.add(mixin.mixinId);
      mixinNamesById[mixin.mixinId] = mixin.mixinName;
      mixinPackagesById[mixin.mixinId] = mixin.mixinPackage;

      final isSamePackage = usage.usagePackage == mixin.mixinPackage;

      final categorizedStats = usageStatsByMixinId.putIfAbsent(
          mixin.mixinId, CategorizedPropsMixinUsageStats.new);

      if (skipReason != null) {
        categorizedStats.skippedUsages
          ..countSkippedUsage(skipReason)
          ..debugSkippedUsages.add(usage.usageId);
      } else {
        categorizedStats.skippedUsages.countNonSkippedUsage();
        for (final stats in [
          categorizedStats.total,
          if (isSamePackage)
            categorizedStats.samePackage
          else
            categorizedStats.otherPackage,
        ]) {
          stats.addPropsCounts(mixin.mixinPropsSet);
          stats.usageCount++;
        }
      }
    }
  }

  // Do this in a second pass after we've processed all props and
  // CategorizedPropsMixinUsageStats.allPropNames is complete for each mixin.
  const unsetThreshold = 0.9;
  const otherNames = {'renderInput', 'options'};
  logger.finer(
      'Collecting usages where props weren\'t set, using threshold $unsetThreshold');
  for (final usage in allUsages) {
    if (getUsageSkipReason(usage) != null) continue;

    for (final mixin in usage.mixinData) {
      final isSamePackage = usage.usagePackage == mixin.mixinPackage;
      final categorizedStats = usageStatsByMixinId[mixin.mixinId];
      // We skipped it above.
      if (categorizedStats == null) continue;
      for (final propName in categorizedStats.allPropNames) {
        if (!mixin.mixinPropsSet.contains(propName)) {
          for (final stats in [
            categorizedStats.total,
            if (isSamePackage)
              categorizedStats.samePackage
            else
              categorizedStats.otherPackage,
          ]) {
            final rateForProp = stats.rateForProp(propName);
            if (otherNames.contains(propName) ||
                (rateForProp != null && rateForProp >= unsetThreshold)) {
              stats.debugUnsetPropUsages
                  .putIfAbsent(propName, () => [])
                  .add(usage.usageId);
            }
          }
        }
      }
    }
  }

  final results = PropRequirednessResults(
    excludeOtherDynamicUsages: excludeOtherDynamicUsages,
    excludeUsagesWithForwarded: excludeUsagesWithForwarded,
    mixinResultsByIdByPackage: {},
    mixinMetadata: MixinMetadata(
      mixinNamesById: mixinNamesById,
      mixinPackagesById: mixinPackagesById,
    ),
  );

  logger.finer('Aggregating final results...');
  for (final mixinId in allMixinIds) {
    final stats = usageStatsByMixinId[mixinId];
    if (stats == null) continue;

    final mixinPackage = mixinPackagesById[mixinId]!;
    final mixinIdsByVisibilityForPackage =
        mixinIdsByVisibilityByPackage[mixinPackage];

    final Visibility visibility;
    if (mixinIdsByVisibilityForPackage == null) {
      // If there's no data for public mixins for a package,
      // then we don't know if it's public or not.
      // We should have this data for all packages we've processed, but it can currently be null
      // for packages that don't have any public entrypoints.
      visibility = Visibility.unknown;
    } else {
      visibility = getVisibilityForMixinIdOrCompanion(
              mixinIdsByVisibilityForPackage,
              mixinId: mixinId,
              mixinName: mixinNamesById[mixinId]!) ??
          Visibility.private;
    }

    final propResultsByName = <String, PropResult>{};
    for (final propName in stats.allPropNames) {
      final samePackageRate = stats.samePackage.rateForProp(propName);
      final samePackageUsageCount = stats.samePackage.countForProp(propName);

      final otherPackageRate = stats.otherPackage.rateForProp(propName);
      final otherPackageUsageCount = stats.otherPackage.countForProp(propName);

      // If we're processing this prop, it'll be non-null for total.
      final totalRate = stats.total.rateForProp(propName)!;
      final totalUsageCount = stats.total.countForProp(propName);

      propResultsByName[propName] = PropResult(
        samePackageRate: samePackageRate,
        otherPackageRate: otherPackageRate,
        totalRate: totalRate,
        samePackageUsageCount: samePackageUsageCount,
        otherPackageUsageCount: otherPackageUsageCount,
        totalUsageCount: totalUsageCount,
        debugSamePackageUnsetUsages: outputDebugData
            ? stats.samePackage.debugUnsetPropUsages[propName]
            : null,
        debugOtherPackageUnsetUsages: outputDebugData
            ? stats.otherPackage.debugUnsetPropUsages[propName]
            : null,
      );
    }

    results.mixinResultsByIdByPackage
        .putIfAbsent(mixinPackage, () => {})[mixinId] = MixinResult(
      visibility: visibility,
      usageSkipCount: stats.skippedUsages.skippedCount,
      usageSkipRate: stats.skippedUsages.skipRate,
      propResultsByName: propResultsByName,
      debugSkippedUsages:
          outputDebugData ? stats.skippedUsages.debugSkippedUsages : null,
    );
  }

  logger.finer('Done.');

  return results;
}

Visibility? getVisibilityForMixinIdOrCompanion(
  Map<Visibility, Set<String>> mixinIdsByVisibility, {
  required String mixinId,
  required String mixinName,
}) {
  late final companionId = (() {
    const legacyBoilerplatePrefix = r'_$';
    if (mixinName.startsWith(legacyBoilerplatePrefix)) {
      // Hack around legacy boilerplate mixins always being private;
      // see if the public companion class is public.
      final publicName = mixinName.substring(legacyBoilerplatePrefix.length);
      return mixinId.replaceFirst(mixinName, publicName);
    }
    return null;
  })();

  final visibility = _getVisibility(mixinIdsByVisibility, mixinId);
  late final companionVisibility = companionId == null
      ? null
      : _getVisibility(mixinIdsByVisibility, companionId);

  return visibility ?? companionVisibility;
}

Visibility? _getVisibility(
    Map<Visibility, Set<String>> mixinIdsByVisibility, String someMixinId) {
  // Prioritize public over indirectly exposed.
  final visibilitiesInPriorityorder =
      (LinkedHashSet.of({Visibility.public})..addAll(Visibility.values));
  return visibilitiesInPriorityorder.firstWhereOrNull((visibility) {
    return mixinIdsByVisibility[visibility]?.contains(someMixinId) ?? false;
  });
}

class CategorizedPropsMixinUsageStats {
  final samePackage = PropsMixinUsageStats();
  final otherPackage = PropsMixinUsageStats();
  final total = PropsMixinUsageStats();

  final skippedUsages = SkippedUsageStats();

  Iterable<String> get allPropNames => total.countsForProps.keys;
}

class SkippedUsageStats {
  var _nonSkippedUsageCount = 0;
  final _skippedCountsByReason = <UsageSkipReason, int>{};

  final List<String> debugSkippedUsages = [];

  int get nonSkippedCount => _nonSkippedUsageCount;

  int get skippedCount =>
      _skippedCountsByReason.values.fold(0, (a, b) => a + b);

  int get totalCount => nonSkippedCount + skippedCount;

  num get skipRate {
    if (totalCount == 0) {
      throw StateError('Cannot compute skip rate when totalCount is 0.');
    }
    return skippedCount / totalCount;
  }

  void countNonSkippedUsage() {
    _nonSkippedUsageCount++;
  }

  void countSkippedUsage(UsageSkipReason reason) {
    _skippedCountsByReason[reason] = (_skippedCountsByReason[reason] ?? 0) + 1;
  }
}

enum UsageSkipReason {
  nonTopLevelFactory,
  hasOtherDynamicProps,
  hasForwardedProps,
}

class PropsMixinUsageStats {
  int usageCount = 0;
  Map<String, int> countsForProps = {};

  Map<String, List<String>> debugUnsetPropUsages = {};

  void addPropsCounts(Iterable<String> propNames) {
    for (final propName in propNames) {
      countsForProps[propName] = (countsForProps[propName] ?? 0) + 1;
    }
  }

  int countForProp(String propName) => countsForProps[propName] ?? 0;

  num? rateForProp(String propName) {
    // Return null instead of a non-finite number.
    if (usageCount == 0) return null;
    return countForProp(propName) / usageCount;
  }
}

class PropsMixin {
  final String mixinId;
  final String packageName;
  final String mixinName;

  PropsMixin._({
    required this.mixinId,
    required this.packageName,
    required this.mixinName,
  });

  factory PropsMixin.fromId(String mixinId) {
    final mixinName = mixinId.split(' - ').first;
    final packageName = RegExp(r'\bpackage:([^/]+)/').firstMatch(mixinId)![1]!;
    return PropsMixin._(
      mixinId: mixinId,
      packageName: packageName,
      mixinName: mixinName,
    );
  }
}