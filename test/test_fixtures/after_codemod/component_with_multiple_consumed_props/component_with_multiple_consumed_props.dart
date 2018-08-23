import 'package:over_react/over_react.dart';

// ignore: uri_does_not_exist
part 'component_with_multiple_consumed_props.generated.dart';

@Factory()
// ignore: undefined_identifier
UiFactory<ComponentInPartProps> ComponentInPart = $ComponentInPart;

@Props()
class ComponentInPartProps extends UiProps {
  // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  static const PropsMeta meta = $metaForComponentInPartProps;

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
  get consumedProps => const [
    AbstractToggleInputGroupProps.meta,
    ToggleButtonGroupProps.meta,
    ButtonGroupPropsMixin.meta,
    FormGroupLabelControlsPairPropsMixin.meta,
  ];

  @override
  render() => Dom.div()();
}

/// Add these class as a placeholder to eliminate analyzer errors.
/// This will not affect how migrater.py performs.
class AbstractToggleInputGroupProps {}
class ButtonGroupPropsMixin {}
class FormGroupLabelControlsPairPropsMixin {}
class ToggleButtonGroupProps {}