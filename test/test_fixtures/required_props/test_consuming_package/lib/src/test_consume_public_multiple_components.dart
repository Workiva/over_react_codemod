import 'package:over_react/over_react.dart';
import 'package:test_package/entrypoint.dart';

class TestMultiComponentsOtherPackageProps = UiProps
    with TestPublicUsedByMultipleComponentsProps;

UiFactory<TestMultiComponentsOtherPackageProps>
    TestMultiComponentsOtherPackage = uiFunction(
  (props) {},
  _$TestMultiComponentsOtherPackageConfig, // ignore: undefined_identifier
);

usages() {
  // 2 usages of mixin in source package, 3 in this package
  (TestMultiComponentsOtherPackage()
    ..set100percent = ''
    ..set80percent = '')();
  (TestMultiComponentsOtherPackage()
    ..set100percent = ''
    ..set80percent = '')();
  (TestMultiComponentsOtherPackage()..set100percent = '')();
}
