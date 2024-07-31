import 'package:over_react/over_react.dart';

part 'test_required_annotations.over_react.g.dart';

mixin TestRequiredAnnotationsProps on UiProps {
  @requiredProp
  String annotatedRequiredProp;
  /// Doc comment
  @requiredProp
  String annotatedRequiredPropWithDocComment;
  @nullableRequiredProp
  String annotatedNullableRequiredProp;
  @requiredProp
  String annotatedRequiredPropNeverSet;
}

UiFactory<TestRequiredAnnotationsProps> TestRequiredAnnotations = uiFunction(
  (props) {},
  _$TestRequiredAnnotationsConfig, // ignore: undefined_identifier
);

usages() {
  (TestRequiredAnnotations()
    ..annotatedRequiredProp = ''
    ..annotatedRequiredPropWithDocComment = ''
    ..annotatedNullableRequiredProp = ''
  )();
}
