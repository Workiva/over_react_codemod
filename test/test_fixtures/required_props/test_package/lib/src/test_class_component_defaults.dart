import 'package:over_react/over_react.dart';

part 'test_class_component_defaults.over_react.g.dart';

mixin TestPrivatePropsMixin on UiProps {
  String notDefaultedOptional;
  String notDefaultedAlwaysSet;
  String defaultedNullable;
  num defaultedNonNullable;
}

mixin SomeOtherPropsMixin on UiProps {
  num anotherDefaultedNonNullable;
}

class TestPrivateProps = UiProps with TestPrivatePropsMixin, SomeOtherPropsMixin;

UiFactory<TestPrivateProps> TestPrivate =
    castUiFactory(_$TestPrivate); // ignore: undefined_identifier

class TestPrivateComponent extends UiComponent2<TestPrivateProps> {
  @override
  get defaultProps => (newProps()
    ..defaultedNullable = null
    ..defaultedNonNullable = 2.1
    ..anotherDefaultedNonNullable = 1.1
  );

  @override
  render() {}
}

mixin TestPublic2PropsMixin on UiProps {
  String notDefaultedOptional;
  String notDefaultedAlwaysSet;
  String defaultedNullable;
  num defaultedNonNullable;
}

class TestPublic2Props = UiProps with TestPublic2PropsMixin, SomeOtherPropsMixin;

UiFactory<TestPublic2Props> TestPublic2 =
castUiFactory(_$TestPublic2); // ignore: undefined_identifier

class TestPublic2Component extends UiComponent2<TestPublic2Props> {
  @override
  get defaultProps => (newProps()
    ..defaultedNullable = null
    ..defaultedNonNullable = 2.1
    ..anotherDefaultedNonNullable = 1.1
  );

  @override
  render() {}
}

usages() {
  (TestPrivate()..notDefaultedAlwaysSet = 'abc')();
  (TestPrivate()
    ..notDefaultedOptional = 'abc'
    ..notDefaultedAlwaysSet = 'abc'
    ..defaultedNullable = 'abc'
    ..defaultedNonNullable = 1
    ..anotherDefaultedNonNullable = 2)();
  (TestPublic2()..notDefaultedAlwaysSet = 'abc')();
  (TestPublic2()..notDefaultedAlwaysSet = 'abc'..notDefaultedOptional = 'abc'..defaultedNullable = 'abc'
    ..defaultedNonNullable = 1
    ..anotherDefaultedNonNullable = 2)();
}
