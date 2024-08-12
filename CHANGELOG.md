## [2.24.0](https://github.com/Workiva/over_react_codemod/compare/2.24.0....2.23.0)

- Add `null_safety_required_props` executable to help [migrate over_react props to nulls safety](https://github.com/Workiva/over_react/blob/master/doc/null_safety/null_safe_migration.md)

#### Changes that don't affect package consumers
- Fix outdated `dart2_upgrade` instructions in README
- Update dev_dependencies, switch to mocktail

## [2.23.0](https://github.com/Workiva/over_react_codemod/compare/2.23.0....2.22.0)

- Update bundle updater codemod to include link tags 

## [2.22.0](https://github.com/Workiva/over_react_codemod/compare/2.22.0....2.21.0)

- Fix for creating two copies of identical messages when they used double quotes

## [2.21.0](https://github.com/Workiva/over_react_codemod/compare/2.21.0....2.20.0)

- Fix names when writing the _intl.dart file

## [2.20.0](https://github.com/Workiva/over_react_codemod/compare/2.20.0....2.19.0)

- Attempt to reduce merge conflicts on _intl.dart files

## [2.19.0](https://github.com/Workiva/over_react_codemod/compare/2.19.0....2.18.0)

- Update the glob for pubspecs to pick up things like empty_pubspec.yaml

## [2.18.0](https://github.com/Workiva/over_react_codemod/compare/2.18.0....2.17.0)

- add shouldAddDependencies to bundle updater codemod

## [2.17.0](https://github.com/Workiva/over_react_codemod/compare/2.17.0....2.16.0)

- Change parameters typed Function in formattedMessage calls to Object

## [2.16.0](https://github.com/Workiva/over_react_codemod/compare/2.16.0....2.15.0)

- Batch change to update consumers to new RMUI ESM bundle

## [2.15.0](https://github.com/Workiva/over_react_codemod/compare/2.15.0....2.14.0)

- Migrate calls to addContextMenuItem
- Fix the ignore for static-only classes to be for the file

## [2.14.0](https://github.com/Workiva/over_react_codemod/compare/2.14.0....2.13.0)

- Add nicer logging to codemod dryrun check 

## [2.13.0](https://github.com/Workiva/over_react_codemod/compare/2.13.0....2.12.0)

- Add a --[no]-prune-unused flag to remove methods that appear to be ununused
  from the _intl.dart file.

## [2.12.0](https://github.com/Workiva/over_react_codemod/compare/2.12.0....2.10.1)

- Add a --[no]-migrate-components option for intl\_message\_migration

## [2.10.1](https://github.com/Workiva/over_react_codemod/compare/2.10.1....2.10.0)

- Switch the import in _intl.dart generated classes to be w\_intl/intl\_wrapper.dart

## [2.10.0](https://github.com/Workiva/over_react_codemod/compare/2.10.0....2.9.0)

- Upgrade to analyzer 2.0
- Improve reporting of parse errors in generated code for intl_message_migration
- Fix a regression where we were getting strings with surrounding quotes from the node,
  and not stripping leading numbers as a result.
- Don't convert SCREAMING_CAPS_CONSTANTS in intl_message_migration

## [2.9.0](https://github.com/Workiva/over_react_codemod/compare/2.9.0....2.8.0)

- Improve the sorting to be by function/getter name rather than the whole function/getter string.
- Allow reading an existing _intl.dart file and rewriting it, preserving the existing functions.
- Turn on the --migrate-constants option by default.

## [2.8.0](https://github.com/Workiva/over_react_codemod/compare/2.8.0....2.7.0)

- Re-enable sorting of the _intl.dart file.

## [2.7.0](https://github.com/Workiva/over_react_codemod/compare/2.7.0....2.6.0)

- Fix type error with adjacent strings.
- Prevent duplicate names for constants by falling back to a content-based name if the variable name is a duplicate.
- Ignore the lint for unnecessary braces in string interpolations in the generated `intl.dart` file.
- Change the name of migrated constant strings to match the original variable instead of being derived from the value.

## [2.6.0]](https://github.com/Workiva/over_react_codemod/compare/2.6.0....2.5.0)

- Make the intl\_message\_migration codemod  handle adjacent strings.
- Make the intl\_message\_migration codemod  allow directories on the
  command line, and default to processing only /lib.
- Fix a bug in intl\_message\_migration codemod  numbering of
  functions that it otherwise couldn't name.


## [1.12.0](https://github.com/Workiva/over_react_codemod/compare/1.12.0...1.11.0)

- Add `dart2_9_upgrade` executable that can either:
  - Upgrade a repo from the mixin based boilerplate to the new factory syntax.
  - Perform a dry run (using the `--check-for-transitioning` flag) to check if the repo has migrated but also contains the now deprecated mixin based factories.

## [1.11.0](https://github.com/Workiva/over_react_codemod/compare/1.11.0...1.10.0)

- Update the `react17_dependency_override_update` codemod to add overrides that point to the release branches for React 17 instead of alpha versions.

## [1.10.0](https://github.com/Workiva/over_react_codemod/compare/1.10.0...1.9.0)

- Add `react17_upgrade` codemod
  - Updates version upper bound of react and over_react in pubspec.yaml to
    allow for incoming React 17 updates.
- Add`react17_dependency_override_update` codemod
  - Adds dependency overrides to pubspec.yaml for testing wip branches of React 17.

## [1.9.0](https://github.com/Workiva/over_react_codemod/compare/1.9.0...1.8.0)

- Fix issue with accessing `isEof` getter on a null token

## [1.8.0](https://github.com/Workiva/over_react_codemod/compare/1.8.0...1.7.0)

Boilerplate codemod fixes and improvements:
- Fix locally-generated semver reports not being readable due to not being nested inside an `{"exports": ...}` object
- Treat FIXMEs converted to TODOs the same as FIXMEs (and don't add new FIXMEs on top of them)
- Account for edge cases when Props were named `${componentName}ComponentProps`
- Ignore common mixins that are known to not implement lifecycle methods and thus shouldn't necessitate migration:
    - TypedSnapshot
    - FocusRestorer (Workiva-specific)
    - FormControlApi/FormControlApiV2 (Workiva-specific)
- Update minimum versions of over_react/over_react_test to include important bugfixes

## [1.7.0](https://github.com/Workiva/over_react_codemod/compare/1.7.0...1.6.0)

- Update boilerplate version updater.
- Fix issues discovered during initial boilerplate rollout.
- Add upgrade instructions.
- Improve handling of newlines in boilerplate upgrades.
- Add additional paths forward for components requiring breaking changes before upgrading.
- Add ability to pass paths or globs to boilerplate_upgrade as basic args to only run the codemod on
the specified files.

## [1.6.0](https://github.com/Workiva/over_react_codemod/compare/1.6.0...1.5.1)

- Add codemod for new boilerplate.
- Create simple props / state boilerplate migrator.
- Add codemod utility to tell if something is public API.
- Remove props/state “companion” classes as part of the boilerplate update.
- Add advanced props migrator.
- Add standalone `PropsMixin` / `StateMixin` migrator.
- Add annotation remover.
- Use utility class to contain map of converted classNames.
- Consume `SemverHelper`.
- Address edge cases for boilerplate codemods.
- Improve class migration short-circuit logic and consumer communication.
- Do final cleanup for new boilerplate codemod.
- Update react and over_react versions for boilerplate migration.
- Address some boilerplate codemod edge cases.
- Preserve `consumedProps` behavior when shorthand used.
- Add `GeneratedPartDirectiveIgnoreRemover` to boilerplate codemod.
- Add suggestor to move factory ignore comments.
- Preserve consumed props behavior defaults.

## [1.5.1](https://github.com/Workiva/over_react_codemod/compare/1.5.1...1.5.0)

- Change the over_react version for the react16_post_rollout_cleanup codemod from ^3.1.0 to ^3.1.3.

## [1.5.0](https://github.com/Workiva/over_react_codemod/compare/1.5.0...1.4.3)

- Use caret deps when possible in version range updates.

## [1.4.3](https://github.com/Workiva/over_react_codemod/compare/1.4.3...1.4.2)

- Revert react16_upgrade change in 1.4.0 that forced over_react to be added whenever just react was listed as a dependency


## [1.4.2](https://github.com/Workiva/over_react_codemod/compare/1.4.1...1.4.2)

- Ignore `.g.dart` files in React 16 codemods.


## [1.4.1](https://github.com/Workiva/over_react_codemod/compare/1.4.0...1.4.1)

- Fix a bug that would cause ErrorBoundary components with props to be wrapped in
  another ErrorBoundary.


## [1.4.0](https://github.com/Workiva/over_react_codemod/compare/1.3.2...1.4.0)

- Update Component2 ComponentWillMountMigrator to migrate the componentWillMount lifecycle code to componentDidMount
- Add React 16 getDefaultProps & getInitialState Migrator
- Add React 16 Post Rollout Codemod
- Update React 16 pubspec updater to include over_react


## [1.3.2](https://github.com/Workiva/over_react_codemod/compare/1.3.1...1.3.2)

- Enable the use of `// orcm_ignore` comments when running the react16 / component2 codemods.


## [1.3.1](https://github.com/Workiva/over_react_codemod/compare/1.3.0...1.3.1)

- Fix a bug that would occur when parsing a pubspec version of "any"


## [1.3.0](https://github.com/Workiva/over_react_codemod/compare/1.2.0...1.3.0)

- Add a flag `--no-partial-upgrades` to `component2_upgrade` codemod that will
  prevent partial component upgrades from occurring.

- Fix a bug that could occur when parsing a pubsec version in
  `dependency_overrides` section.


## [1.2.0](https://github.com/Workiva/over_react_codemod/compare/1.1.0...1.2.0)

- Add `react16_upgrade` codemod

  - Fix compatibility issues common in react15 code.
  - Update version upper bound of react and over_react in pubspec.yaml to
    allow for incoming react16 updates.

- Add `component2_upgrade` codemod

  - Migrates components to `UiComponent2` (coming in over_react 3.1.0)

- Add `react16_dependency_override_update` codemod

  - Adds dependency overrides to pubspec.yaml for testing wip branches of React 16

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
