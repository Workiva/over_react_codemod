import 'package:over_react/over_react.dart';

part 'test_private_non_factory_usages.over_react.g.dart';

mixin TestPrivateNonFactoryUsagesProps on UiProps {
  String set100percent;
  String onlySetOnNonFactoryUsages;
}

UiFactory<TestPrivateNonFactoryUsagesProps> TestPrivateNonFactoryUsages =
    uiFunction(
  (props) {},
  _$TestPrivateNonFactoryUsagesConfig, // ignore: undefined_identifier
);

class SomeObject {
  UiFactory<TestPrivateNonFactoryUsagesProps> factoryProperty;
}

usages(SomeObject object) {
  // A single usage to make sure we're collecting data for these props.
  (TestPrivateNonFactoryUsages()..set100percent = '')();
  {
    final factoryLocalVariable = TestPrivateNonFactoryUsages;
    (factoryLocalVariable()
      ..set100percent = ''
      ..onlySetOnNonFactoryUsages = '')();
  }
  {
    final builderLocalVariable = TestPrivateNonFactoryUsages();
    (builderLocalVariable
      ..set100percent = ''
      ..onlySetOnNonFactoryUsages = '')();
  }
  {
    (object.factoryProperty()
      ..set100percent = ''
      ..onlySetOnNonFactoryUsages = '')();
  }
}
