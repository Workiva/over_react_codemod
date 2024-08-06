import 'package:over_react/over_react.dart';

part 'test_private_dynamic.over_react.g.dart';

mixin TestPrivateDynamicProps on UiProps {
  String set100percent;
}

UiFactory<TestPrivateDynamicProps> TestPrivateDynamic = uiFunction(
  (props) {},
  _$TestPrivateDynamicConfig, // ignore: undefined_identifier
);

void dynamicUsages(Map props, void Function(Map) propsModifier) {
  // Test all dynamic usage cases.
  // 75% of usages are dynamic.

  // One non-dynamic usage to help assert we're collecting data properly.
  (TestPrivateDynamic()..set100percent = '')();

  (TestPrivateDynamic()
    ..addProps(props)
    ..set100percent = '')();
  (TestPrivateDynamic()
    ..addAll(props)
    ..set100percent = '')();
  (TestPrivateDynamic()
    ..modifyProps(propsModifier)
    ..set100percent = '')();
}

mixin TestPrivateForwardedProps on UiProps {
  String set100percent;
}

UiFactory<TestPrivateForwardedProps> TestPrivateForwarded = uiFunction(
  (props) {},
  _$TestPrivateForwardedConfig, // ignore: undefined_identifier
);

abstract class ForwardedUsagesComponent extends UiComponent2 {
  void forwardedUsages() {
    // Test all forwarded usage cases.

    // One non-dynamic usage to help assert we're collecting data properly.
    (TestPrivateForwarded()..set100percent = '')();

    (TestPrivateForwarded()
      ..set100percent = ''
      ..addProps(copyUnconsumedProps()))();
    (TestPrivateForwarded()
      ..modifyProps(addUnconsumedProps)
      ..set100percent = '')();

    (TestPrivateForwarded()
      ..set100percent = ''
      ..addProps(props.getPropsToForward()))();
    (TestPrivateForwarded()
      ..set100percent = ''
      ..modifyProps(props.addPropsToForward()))();

    (TestPrivateForwarded()
      ..addUnconsumedProps(props, [])
      ..set100percent = '')();
  }
}
