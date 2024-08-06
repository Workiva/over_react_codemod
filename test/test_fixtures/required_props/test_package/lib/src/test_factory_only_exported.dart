import 'package:meta/meta.dart';
import 'package:over_react/over_react.dart';

part 'test_factory_only_exported.over_react.g.dart';

@internal
mixin TestFactoryOnlyExportedProps on UiProps {
  String set100percent;
}

UiFactory<TestFactoryOnlyExportedProps> TestFactoryOnlyExported = uiFunction(
  (props) {},
  _$TestFactoryOnlyExportedConfig, // ignore: undefined_identifier
);

usages() {
  (TestFactoryOnlyExported()..set100percent = '')();
}
