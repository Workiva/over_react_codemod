import 'package:over_react/over_react.dart';

mixin TestPrivateUsedByMultipleComponentsProps on UiProps {
  String set100percent;
  String set80percent;
  String set20percent;
  String set0percent;
}

class TestMultiComponents1Props = UiProps
    with TestPrivateUsedByMultipleComponentsProps;

UiFactory<TestPrivateUsedByMultipleComponentsProps> TestMultiComponents1 =
    uiFunction(
  (props) {},
  _$TestMultiComponents1Config, // ignore: undefined_identifier
);

class TestMultiComponents2Props = UiProps
    with TestPrivateUsedByMultipleComponentsProps;

UiFactory<TestPrivateUsedByMultipleComponentsProps> TestMultiComponents2 =
    uiFunction(
  (props) {},
  _$TestMultiComponents2Config, // ignore: undefined_identifier
);

usages() {
  (TestMultiComponents1()
    ..set100percent = ''
    ..set80percent = ''
    ..set20percent = '')();
  (TestMultiComponents1()
    ..set100percent = ''
    ..set80percent = '')();
  (TestMultiComponents1()
    ..set100percent = ''
    ..set80percent = '')();
  (TestMultiComponents1()
    ..set100percent = ''
    ..set80percent = '')();

  (TestMultiComponents2()..set100percent = '')();
}
