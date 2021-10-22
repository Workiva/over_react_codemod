import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import '../constants.dart';
import 'mui_migrator.dart';

class MuiButtonToolbarMigrator extends ComponentUsageMigrator with MuiMigrator {
  @override
  ShouldMigrateDecision shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'ButtonToolbar')
          ? ShouldMigrateDecision.yes
          : ShouldMigrateDecision.no;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    yieldPatchOverNode('$muiNs.ButtonToolbar', usage.factory!);
  }
}
