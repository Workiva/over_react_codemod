import 'package:over_react/over_react.dart';

mixin TestPublicUsedByMultipleComponentsProps on UiProps {
  String set100percent;
  String set80percent;
  String set20percent;
  String set0percent;
}

class _TestMultiComponentsSamePackageProps = UiProps
    with TestPublicUsedByMultipleComponentsProps;

UiFactory<_TestMultiComponentsSamePackageProps>
    _TestMultiComponentsSamePackage = uiFunction(
  (props) {},
  _$_TestMultiComponentsSamePackageConfig, // ignore: undefined_identifier
);

usages() {
  // 2 usages of mixin in this package, 3 in consuming package
  (_TestMultiComponentsSamePackage()
    ..set100percent = ''
    ..set80percent = ''
    ..set20percent = '')();
  (_TestMultiComponentsSamePackage()
    ..set100percent = ''
    ..set80percent = '')();
}
