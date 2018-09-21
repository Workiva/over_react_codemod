import 'package:over_react/over_react.dart';

// ignore: uri_does_not_exist
part 'component_with_multiple_consumed_props.generated.dart';

@Factory()
// ignore: undefined_identifier
UiFactory<ComponentWithMultipleConsumedPropsProps> ComponentWithMultipleConsumedProps = $ComponentWithMultipleConsumedProps;

@Props()
class ComponentWithMultipleConsumedPropsProps extends UiProps {
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForComponentWithMultipleConsumedPropsProps;

  @requiredProp
  var required;

  @nullableRequiredProp
  var nullable;
}

@Component()
class ComponentWithMultipleConsumedPropsComponent extends UiComponent<ComponentWithMultipleConsumedPropsProps> {
  @override
  get consumedProps => const [
    AbstractToggleInputGroupProps.meta,
    ToggleButtonGroupProps.meta,
  ];

  @override
  render() => Dom.div()();
}

/// Add these class as a placeholder to eliminate analyzer errors.
/// This will not affect how migrater.py performs.
class AbstractToggleInputGroupProps {}
class ToggleButtonGroupProps {}