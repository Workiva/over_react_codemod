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

import 'package:json_annotation/json_annotation.dart';

part 'aggregated_data.sg.g.dart';

@JsonSerializable()
class PropRequirednessResults {
  final bool excludeOtherDynamicUsages;
  final bool excludeUsagesWithForwarded;

  final Map<String, Map<String, MixinResult>> mixinResultsByIdByPackage;

  final MixinMetadata mixinMetadata;

  factory PropRequirednessResults.fromJson(Map<String, dynamic> json) =>
      _$PropRequirednessResultsFromJson(json);

  PropRequirednessResults({
    required this.excludeOtherDynamicUsages,
    required this.excludeUsagesWithForwarded,
    required this.mixinResultsByIdByPackage,
    required this.mixinMetadata,
  });

  Map<String, dynamic> toJson() => _$PropRequirednessResultsToJson(this);
}

@JsonSerializable()
class MixinMetadata {
  final Map<String, String> mixinNamesById;
  final Map<String, String> mixinPackagesById;

  MixinMetadata({
    required this.mixinNamesById,
    required this.mixinPackagesById,
  });

  factory MixinMetadata.fromJson(Map<String, dynamic> json) => _$MixinMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$MixinMetadataToJson(this);
}

@JsonSerializable(includeIfNull: false)
class MixinResult {
  final Visibility visibility;
  final int usageSkipCount;
  final num usageSkipRate;
  final Map<String, PropResult> propResultsByName;
  final List<String>? debugSkippedUsages;

  MixinResult({
    required this.visibility,
    required this.usageSkipCount,
    required this.usageSkipRate,
    required this.propResultsByName,
    this.debugSkippedUsages,
  });

  factory MixinResult.fromJson(Map<String, dynamic> json) => _$MixinResultFromJson(json);

  Map<String, dynamic> toJson() => _$MixinResultToJson(this);
}

@JsonSerializable(includeIfNull: false)
class PropResult {
  final num? samePackageRate;
  final num? otherPackageRate;
  final num totalRate;
  final int samePackageUsageCount;
  final int otherPackageUsageCount;
  final int totalUsageCount;
  final List<String>? debugSamePackageUnsetUsages;
  final List<String>? debugOtherPackageUnsetUsages;

  PropResult({
    required this.samePackageRate,
    required this.otherPackageRate,
    required this.totalRate,
    required this.samePackageUsageCount,
    required this.otherPackageUsageCount,
    required this.totalUsageCount,
    this.debugSamePackageUnsetUsages,
    this.debugOtherPackageUnsetUsages,
  });

  factory PropResult.fromJson(Map<String, dynamic> json) => _$PropResultFromJson(json);

  Map<String, dynamic> toJson() => _$PropResultToJson(this);
}

enum Visibility {
  public,
  indirectlyPublic,
  private,
  unknown,
}
