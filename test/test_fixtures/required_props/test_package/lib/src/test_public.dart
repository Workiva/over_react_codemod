import 'package:over_react/over_react.dart';

part 'test_public.g.dart';

mixin TestPublicProps on UiProps {
  String set100percent;
}

UiFactory<TestPublicProps> TestPublic = uiFunction(
  (props) {},
  _$TestPublicConfig, // ignore: undefined_identifier
);

usages() {
  (TestPublic()..set100percent = '')();
  (TestPublic()..set100percent = '')();
  (TestPublic()..set100percent = '')();
  (TestPublic()..set100percent = '')();
  (TestPublic()..set100percent = '')();
}
