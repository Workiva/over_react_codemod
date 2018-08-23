import 'package:over_react/over_react.dart';

@Factory()
UiFactory<ComponentInPartProps> ComponentInPart;

@Props()
class ComponentInPartProps extends UiProps {}

@Component()
class ComponentInPartComponent extends UiComponent<ComponentInPartProps> {
  @override
  render() => Dom.div()();
}