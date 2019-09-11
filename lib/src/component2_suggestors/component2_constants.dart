// Copyright 2019 Workiva Inc.
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

import 'package:meta/meta.dart';

const revertInstructions = '/// These updates are opt-in and can be '
    'rolled back if you do not wish to do the update at this time.';

String methodDeprecationMessage({@required String methodName}) {
  final updateInstructionLink =
      'https://reactjs.org/docs/react-component.html#unsafe_${methodName.toLowerCase()}';

  return '''
        /// FIXME: [$methodName] has been deprecated and is now considered unsafe. 
        ///
        /// Please see the doc comment for [$methodName] or visit 
        /// $updateInstructionLink
        /// for more details on updating.''';
}

String getDeperecationMessage(String methodName) {
  return '''
  ${methodDeprecationMessage(methodName: '$methodName')}
  ///
  $revertInstructions''';
}

String componentWillMountMessage = '''
  /// FIXME: Method has been renamed from `componentWillMount` to `componentDidMount`. Please check if super call should be added or updated.''';
