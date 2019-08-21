const fixmePrefix = 'FIXME:over_react_codemod';

const manualValidationCommentSubstring = 'Check this box upon manual';

const willBeRemovedCommentSuffix =
    ' This will be removed once the transition to React 16 is complete.';

const styleMapExample = '''
    // CSS number strings are no longer auto-converted to px. Ensure values are of type `num`, or have units.
    // Incorrect value for 'width': '40'. Correct values: 40, '40px', '4em'.''';
