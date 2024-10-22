import 'dart:html';

import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';

// ignore: uri_has_not_been_generated
part 'test_state.over_react.g.dart';

UiFactory<FooProps> Foo = connect<FooState, FooProps>(
  mapStateToPropsWithOwnProps: (state, props) => Foo()..prop1 = 1,
)(castUiFactory(_$Hoc)); // ignore: undefined_identifier

mixin FooProps on UiProps {
  int prop1;
  int prop2;
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
