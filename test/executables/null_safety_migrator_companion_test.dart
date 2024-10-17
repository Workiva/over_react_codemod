// Copyright 2024 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'required_props_collect_and_codemod_test.dart';

void main() {
  group('null_safety_migrator_companion codemod, end-to-end behavior:', () {
    final companionScript = p.join(findPackageRootFor(p.current),
        'bin/null_safety_migrator_companion.dart');

    const name = 'test_package';
    late d.DirectoryDescriptor projectDir;

    setUp(() async {
      projectDir = d.DirectoryDescriptor.fromFilesystem(
          name,
          p.join(findPackageRootFor(p.current),
              'test/test_fixtures/required_props/test_package'));
      await projectDir.create();
    });

    test('adds hints as expected in different cases', () async {
      await testCodemod(
        script: companionScript,
        args: [
          '--yes-to-all',
        ],
        input: projectDir,
        expectedOutput: d.dir(projectDir.name, [
          d.dir('lib', [
            d.dir('src', [
              d.file('test_state.dart', contains('''
mixin FooProps on UiProps {
  int prop1;
}

mixin FooState on UiState {
  String/*?*/ state1;
  /*late*/ int/*!*/ initializedState;
  void Function()/*?*/ state2;
}

class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
  @override
  get initialState => (newState()..initializedState = 1);

  @override
  render() {
    ButtonElement/*?*/ _ref;
    return (Dom.div()..ref = (ButtonElement/*?*/ r) => _ref = r)();
  }
}''')),
            ]),
          ]),
        ]),
      );
    });
  }, timeout: Timeout(Duration(minutes: 2)));
}
