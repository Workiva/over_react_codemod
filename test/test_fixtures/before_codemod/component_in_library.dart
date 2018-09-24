import 'package:over_react/over_react.dart';

@Factory()
UiFactory<ComponentInLibraryProps> ComponentInLibrary;

@Props()
class ComponentInLibraryProps extends UiProps {}

@Component()
class ComponentInLibraryComponent extends UiComponent<ComponentInLibraryProps> {
  @override
  render() => Dom.div()();
}