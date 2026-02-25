import 'package:over_react/over_react.dart';

part 'text_field.over_react.g.dart';

UiFactory<TextFieldProps> TextField = uiFunction((_) {}), _$TextFieldConfig);

@Props(keyNamespace: '')
mixin TextFieldProps on UiProps {
  @convertJsMapProp
  Map? sx;

  @Deprecated('Deprecated, but not the same as the system props color')
  dynamic color;
}
