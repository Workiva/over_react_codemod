## [1.1.0](https://github.com/Workiva/over_react_codemod/compare/1.0.2...1.1.0)

- Two additional changes are now made by the `dart2_upgrade` codemod when
  running without the `--backwards-compat` flag:

  - `// orcm_ignore` comments are removed
  - `// ignore: uri_has_not_been_generated` comments that precede a
    `.over_react.g.dart` part directive are removed

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
