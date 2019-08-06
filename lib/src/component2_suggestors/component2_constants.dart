const revertInstructions = '/// These updates are opt-in and can be '
    'rolled back if you do not wish to do the update at this time.';

String methodDeprecationMessage({methodName}) =>
    '/// FIXME: [$methodName] has been '
    'deprecated and should be updated to [unsafe_$methodName]. Please see '
    'the doc comment for [$methodName] for more details on updating.';

String getComponentWillUpdateComment() => '''
  ${methodDeprecationMessage(methodName: 'componentWillUpdate')}
  ///
  $revertInstructions''';

String getComponentWillReceivePropsComment() => '''
  ${methodDeprecationMessage(methodName: 'componentWillReceiveProps')}
  ///
  $revertInstructions''';
