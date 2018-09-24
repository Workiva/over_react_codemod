import 'package:over_react/over_react.dart';

@Factory()
UiFactory<ComponentWithMultipleConsumedPropsProps> ComponentWithMultipleConsumedProps;

@Props()
class ComponentWithMultipleConsumedPropsProps extends UiProps {
  @requiredProp
  var required;

  @nullableRequiredProp
  var nullable;
}

@Component()
class ComponentWithMultipleConsumedPropsComponent extends UiComponent<ComponentWithMultipleConsumedPropsProps> {
  @override
  get consumedProps => const [
    const $Props(AbstractToggleInputGroupProps),
    const $Props(ToggleButtonGroupProps),
  ];

  @override
  render() => Dom.div()();
}

/// Add these class as a placeholder to eliminate analyzer errors.
/// This will not affect how migrater.py performs.
class AbstractToggleInputGroupProps {}
class ToggleButtonGroupProps {}