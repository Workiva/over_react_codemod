import 'package:over_react/over_react.dart';

part 'test_private.over_react.g.dart';

mixin TestPrivateExistingHintsProps on UiProps {
  String set100percentWithoutHint;

  /*late*/ String set100percent;
  String /*?*/ set80percent;
  String /*?*/ set0percent;
}

UiFactory<TestPrivateExistingHintsProps> TestPrivateExistingHints = uiFunction(
  (props) {},
  _$TestPrivateExistingHintsConfig, // ignore: undefined_identifier
);

usages() {
  (TestPrivateExistingHints()
    ..set100percentWithoutHint = ''
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivateExistingHints()
    ..set100percentWithoutHint = ''
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivateExistingHints()
    ..set100percentWithoutHint = ''
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivateExistingHints()
    ..set100percentWithoutHint = ''
    ..set100percent = ''
    ..set80percent = '')();
  (TestPrivateExistingHints()
    ..set100percentWithoutHint = ''
    ..set100percent = '')();
}
