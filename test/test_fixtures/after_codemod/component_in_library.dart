import 'package:over_react/over_react.dart';

// ignore: uri_does_not_exist
part 'component_in_library.generated.dart';

@Factory()
// ignore: undefined_identifier
UiFactory<ComponentInLibraryProps> ComponentInLibrary = $ComponentInLibrary;

@Props()
class ComponentInLibraryProps extends UiProps {
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForComponentInLibraryProps;
}

@Component()
class ComponentInLibraryComponent extends UiComponent<ComponentInLibraryProps> {
  @override
  render() => Dom.div()();
}