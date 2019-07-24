const fixmePrefix = 'FIXME:over_react_codemod';

const manualValidationCommentSubstring = 'Check this box upon manual validation';

const willBeRemovedCommentSuffix = ' This will be removed once the transition to React 16 is complete.';

const styleMapExample =
    '''
    // If the property accepts a numerical value:
    // Incorrect: 'width': '40'
    // Correct: 'width': 40 or 'width': '40px' or 'width': '4em' etc''';