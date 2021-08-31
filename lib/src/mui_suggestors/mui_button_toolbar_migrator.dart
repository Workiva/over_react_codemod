import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import 'constants.dart';

class MuiButtonToolbarMigrator extends Object
    with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'ButtonToolbar')
          ? MigrationDecision.shouldMigrate
          : MigrationDecision.notApplicable;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    yieldPatchOverNode('$muiNs.ButtonToolbar', usage.factory!);
  }
}
