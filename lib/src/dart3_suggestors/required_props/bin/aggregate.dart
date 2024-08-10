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

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import '../collect/aggregate.dart';
import '../collect/logging.dart';

/// Aggregates individual data files, like what the collect command does,
/// but as a standalone command.
///
/// This is leftover from before the collect command also aggregated data,
/// and is not publicly exposed, but is left in place just in case for
/// debugging purposes and potential future use.
///
/// Also outputs some additional statistics.
Future<void> main(List<String> args) async {
  final argParser = ArgParser()
    ..addFlag('help', help: 'Print this usage information', negatable: false)
    ..addOption(
      'output',
      abbr: 'o',
      help: 'The file to write output to.',
      valueHelp: 'path',
      defaultsTo: defaultAggregatedOutputFile,
    );
  final parsedArgs = argParser.parse(args);
  if (parsedArgs['help'] as bool) {
    print(argParser.usage);
    exit(ExitCode.success.code);
  }
  final outputFile = parsedArgs['output']! as String;
  final filesToAggregate = parsedArgs.rest;
  if (filesToAggregate.isEmpty) {
    print('Must specify files to aggregate.\n${argParser.usage}');
    exit(ExitCode.usage.code);
  }

  initLogging();
  final logger = Logger('prop_requiredness_aggregate');

  logger.info('Loading results from files specified in arguments...');
  final allResults = loadResultFiles(filesToAggregate);

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
