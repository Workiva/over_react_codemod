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

import 'package:json_annotation/json_annotation.dart';

import 'aggregated_data.sg.dart' show Visibility;
export 'aggregated_data.sg.dart' show Visibility;

part 'collected_data.sg.g.dart';

@JsonSerializable()
class PackageResults {
  static String latestDataVersion = '14';

  final String dataVersion;

  final String packageName;
  final Set<String> otherPackageNames;
  final Map<String, String> packageVersionDescriptionsByName;
  final List<Usage> usages;
  final Map<String, Map<Visibility, Set<String>>> mixinIdsByVisibilityByPackage;
  final Map<String, Map<Visibility, Set<String>>> stateMixinIdsByVisibilityByPackage;
  final Map<String, Set<String>> allMixinUsagesByMixinId;

  factory PackageResults.fromJson(Map<String, dynamic> json) =>
      _$PackageResultsFromJson(json);

  PackageResults({
    required this.dataVersion,
    required this.packageName,
    required this.otherPackageNames,
    required this.packageVersionDescriptionsByName,
    required this.usages,
    required this.mixinIdsByVisibilityByPackage,
    required this.stateMixinIdsByVisibilityByPackage,
    required this.allMixinUsagesByMixinId,
  });

  Map<String, dynamic> toJson() => _$PackageResultsToJson(this);
}

PackageResults? tryParseResults(String potentialJson) {
  try {
    return PackageResults.fromJson(
        (jsonDecode(potentialJson) as Map).cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

@JsonSerializable()
class Usage {
  final String usageId;
  final String usageUri;
  final String usagePackage;
  final UsageDebugInfo? usageDebugInfo;
  final bool usageHasOtherDynamicProps;
  final bool usageHasForwardedProps;
  final BuilderType usageBuilderType;
  final List<UsageMixinData> mixinData;

  Usage({
    required this.usageId,
    required this.usageUri,
    required this.usagePackage,
    this.usageDebugInfo,
    required this.usageHasOtherDynamicProps,
    required this.usageHasForwardedProps,
    required this.usageBuilderType,
    required this.mixinData,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);

  Map<String, dynamic> toJson() => _$UsageToJson(this);
}

@JsonSerializable()
class UsageDebugInfo {
  final String usageBuilderSource;

  UsageDebugInfo({required this.usageBuilderSource});

  factory UsageDebugInfo.fromJson(Map<String, dynamic> json) =>
      _$UsageDebugInfoFromJson(json);

  Map<String, dynamic> toJson() => _$UsageDebugInfoToJson(this);
}

@JsonSerializable()
class UsageMixinData {
  final String mixinPackage;
  final String mixinId;
  final String mixinName;
  final Set<String> mixinPropsSet;

  UsageMixinData({
    required this.mixinPackage,
    required this.mixinId,
    required this.mixinName,
    required this.mixinPropsSet,
  });

  factory UsageMixinData.fromJson(Map<String, dynamic> json) =>
      _$UsageMixinDataFromJson(json);

  Map<String, dynamic> toJson() => _$UsageMixinDataToJson(this);
}

enum BuilderType {
  topLevelFactory,
  otherFactory,
  otherBuilder,
}
