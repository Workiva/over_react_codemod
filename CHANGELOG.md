## [1.3.0](https://github.com/Workiva/over_react_codemod/compare/1.2.0...1.3.0)

- Add a flag --no-partial-upgrades to Component2 codemod executable that will
  prevent partial component upgrades from occurring.

- Fix a bug that could occur when parsing a pubsec version in `dependency_overrides` section.


## [1.2.0](https://github.com/Workiva/over_react_codemod/compare/1.1.0...1.2.0)

- Add `react16_upgrade` codemod

  - Fix compatibility issues common in react15 code.
  - Update version upper bound of react and over_react in pubspec.yaml to
    allow for incoming react16 updates.

- Add `component2_upgrade` codemod

  - Migrates components to `UiComponent2` (coming in OverReact 3.1.0)

- Add `react16_dependency_override_update` codemod

  - Adds dependency overrides to pubspec.yaml for testing wip branches of react16

- Add `react16_ci_precheck` codemod

  - Checks the version ranges of over_react and react and if they are in
    transition will run the codemod and fail if there are unaddressed issues.


## [1.1.0](https://github.com/Workiva/over_react_codemod/compare/1.0.2...1.1.0)

- Two additional changes are now made by the `dart2_upgrade` codemod when
  running without the `--backwards-compat` flag:

  - `// orcm_ignore` comments are removed
  - `// ignore: uri_has_not_been_generated` comments that precede a
    `.over_react.g.dart` part directive are removed

- Fix a bug that could result in overlapping patches being suggested, which
  would cause the `dart2_upgrade` codemod to exit early unsuccessfully.

## [1.0.2](https://github.com/Workiva/over_react_codemod/compare/1.0.1...1.0.2)

- Provide additional output from the `dart2_upgrade` codemod in the following
  two scenarios:

  - When running with the `-h|--help` flag
  - When running with the `--fail-on-changes` flag

## [1.0.1](https://github.com/Workiva/over_react_codemod/compare/1.0.0...1.0.1)

- Fix a bug with removing the `// ignore: undefined_identifier` comment from
  UI Factories when running `over_react_codemod:dart2_upgrade` without the
  `--backwards-compat` flag.

## [1.0.0](https://github.com/Workiva/over_react_codemod/compare/00f8644...1.0.0)

- Initial release!
