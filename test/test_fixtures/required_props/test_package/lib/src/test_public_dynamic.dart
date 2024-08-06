import 'package:over_react/over_react.dart';

part 'test_public_dynamic.over_react.g.dart';

mixin TestPublicDynamicProps on UiProps {
  String set100percent;
}

UiFactory<TestPublicDynamicProps> TestPublicDynamic = uiFunction(
  (props) {},
  _$TestPublicDynamicConfig, // ignore: undefined_identifier
);

void dynamicUsages(Map props) {
  // 80% of usages are dynamic.

  // One non-dynamic usage to help assert we're collecting data properly.
  (TestPublicDynamic()..set100percent = '')();
  (TestPublicDynamic()
    ..addProps(props)
    ..set100percent = '')();
  (TestPublicDynamic()
    ..addProps(props)
    ..set100percent = '')();
  (TestPublicDynamic()
    ..addProps(props)
    ..set100percent = '')();
  (TestPublicDynamic()
    ..addProps(props)
    ..set100percent = '')();
}
