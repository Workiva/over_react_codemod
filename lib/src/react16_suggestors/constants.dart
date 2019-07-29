const fixmePrefix = 'FIXME:over_react_codemod';

const manualValidationCommentSubstring =
    'Check this box upon manual';

const willBeRemovedCommentSuffix =
    ' This will be removed once the transition to React 16 is complete.';

const manualUpdateComment = '\n'
    '// [ ] Check this box upon manually updating this argument to use a callback ref instead of the return value of `react_dom.render`.'
//    '// Example: \n'
//    '// Before: `instance = getDartComponent(react_dom.render(Foo()(), mountNode));` \n'
//    '// After: `react_dom.render((Foo()..ref = (ref) { instance = ref; })(), mountNode);` \n'
    '$willBeRemovedCommentSuffix \n';
