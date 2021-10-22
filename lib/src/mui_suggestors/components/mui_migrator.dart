import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

mixin MuiMigrator on ComponentUsageMigrator {
  @override
  String get fixmePrefix => 'FIXME(mui_migration)';
}
