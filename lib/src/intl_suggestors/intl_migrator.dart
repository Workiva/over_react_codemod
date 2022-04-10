import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

mixin IntlMigrator on ComponentUsageMigrator {
  @override
  String get fixmePrefix => 'FIXME(intl_migration)';
  @override
  bool get shouldFlagUnsafeMethodCalls => false;
  @override
  bool get shouldFlagUntypedSingleProp => false;
  @override
  bool get shouldFlagRefProp => false;
  @override
  bool get shouldFlagClassName => false;
  @override
  bool get shouldFlagExtensionMembers => false;
  @override
  bool get shouldFlagPrefixedProps => false;
}
