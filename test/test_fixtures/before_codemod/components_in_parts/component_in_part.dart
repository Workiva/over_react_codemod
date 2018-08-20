import 'package:over_react/over_react.dart';

@Factory()
UiFactory<ComponentInPartProps> ComponentInPart;

@Props()
class ComponentInPartProps extends UiProps {
  // ignore: deprecated_member_use
  @Required(message: 'This Prop is Required for testing purposes.')
  var required;

  // ignore: deprecated_member_use
  @Required(isNullable: true, message: 'This prop can be set to null!')
  var nullable;
}

@Component()
class ComponentInPartComponent extends UiComponent<ComponentInPartProps> {
  @override
  render() => Dom.div()();
}