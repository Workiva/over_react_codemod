import 'dart:html';

import 'package:over_react/over_react.dart';

// ignore: uri_has_not_been_generated
part 'test_state.over_react.g.dart';

UiFactory<FooProps> Foo =
    castUiFactory(_$Foo); // ignore: undefined_identifier

mixin FooProps on UiProps {
  int prop1;
}

mixin FooState on UiState {
  String state1;
  int initializedState;
  void Function() state2;
}

class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
  @override
  get initialState => (newState()..initializedState = 1);

  @override
  render() {
    ButtonElement _ref;
    return (Dom.div()..ref = (ButtonElement r) => _ref = r)();
  }
}
