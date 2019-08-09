import 'package:meta/meta.dart';

const revertInstructions = '/// These updates are opt-in and can be '
    'rolled back if you do not wish to do the update at this time.';

String methodDeprecationMessage({@required methodName}) {
  final updateInstructionLink =
      'https://reactjs.org/docs/react-component.html#updating-$methodName';

  return '''
        /// FIXME: [$methodName] has been deprecated and is now considered unsafe. 
        ///
        /// Please see the doc comment for [$methodName] or visit 
        /// $updateInstructionLink
        /// for more details on updating.''';
}

String getComponentWillUpdateComment() => '''
  ${methodDeprecationMessage(methodName: 'componentWillUpdate')}
  ///
  $revertInstructions''';

String getComponentWillReceivePropsComment() => '''
  ${methodDeprecationMessage(methodName: 'componentWillReceiveProps')}
  ///
  $revertInstructions''';
