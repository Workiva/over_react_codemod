part of test_component_library;

@Factory()
UiFactory<ComponentInPartProps> ComponentInPart;

@Props()
class ComponentInPartProps extends UiProps {}

@Component()
class ComponentInPartComponent extends UiComponent<ComponentInPartProps> {
  @override
  render() => Dom.div()();
}