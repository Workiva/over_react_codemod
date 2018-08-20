part of test_component_library_before;

@Factory()
UiFactory<ComponentInLibraryProps> ComponentInLibrary;

@Props()
class ComponentInLibraryProps extends UiProps {
  // ignore: deprecated_member_use
  @Required(message: 'This Prop is Required for testing purposes.')
  var required;

  // ignore: deprecated_member_use
  @Required(isNullable: true, message: 'This prop can be set to null!')
  var nullable;
}

@Component()
class ComponentInLibraryComponent extends UiComponent<ComponentInLibraryProps> {
  @override
  render() => Dom.div()();
}