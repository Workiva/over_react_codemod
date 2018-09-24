part of test_component_library;

@Factory()
// ignore: undefined_identifier
UiFactory<ComponentInPartProps> ComponentInPart = $ComponentInPart;

@Props()
class ComponentInPartProps extends UiProps {
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForComponentInPartProps;
}

@Component()
class ComponentInPartComponent extends UiComponent<ComponentInPartProps> {
  @override
  render() => Dom.div()();
}