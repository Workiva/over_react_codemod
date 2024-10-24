import 'package:over_react/over_react.dart';

part 'test_private.over_react.g.dart';

mixin TestPrivateProps on UiProps {
  late String set100percent;
  String? set80percent;
  String? set20percent;
  String? set0percent;
}

UiFactory<TestPrivateProps> TestPrivate = uiFunction(
  (props) {},
  _$TestPrivateConfig, // ignore: undefined_identifier
);

usages() {
  (TestPrivate()
    ..set100percent = ''
    ..set80percent = ''
    ..set20percent = '')();
  (TestPrivate()
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivate()
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivate()
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivate()..set100percent = '')();
}
