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
