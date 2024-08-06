import 'package:over_react/over_react.dart';

part 'test_required_annotations.over_react.g.dart';

mixin TestRequiredAnnotationsProps on UiProps {
  @requiredProp
  String annotatedRequiredProp;
  @nullableRequiredProp
  String annotatedNullableRequiredProp;

  @requiredProp
  String annotatedRequiredPropSet50Percent;
  @requiredProp
  String annotatedRequiredPropSet0Percent;

  /// Doc comment
  @requiredProp
  String annotatedRequiredPropWithDocComment;
}

UiFactory<TestRequiredAnnotationsProps> TestRequiredAnnotations = uiFunction(
  (props) {},
  _$TestRequiredAnnotationsConfig, // ignore: undefined_identifier
);

usages() {
  (TestRequiredAnnotations()
    ..annotatedRequiredProp = ''
    ..annotatedNullableRequiredProp = ''
    ..annotatedRequiredPropWithDocComment = '')();
  (TestRequiredAnnotations()
    ..annotatedRequiredProp = ''
    ..annotatedNullableRequiredProp = ''
    ..annotatedRequiredPropWithDocComment = ''
    ..annotatedRequiredPropSet50Percent = '')();
}
