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
