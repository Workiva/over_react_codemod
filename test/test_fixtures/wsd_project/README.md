A package that depends on web_skin_dart, and can be used as a context root for tests that require a resolved analysis context with access to web_skin_dart APIs.

This is separate from over_react_project, since web_skin_dart is only required for some tests, and fetching it as a dependency requires access to a private Pub server, meaning it can't be run in GitHub Actions. 

To use, see `SharedAnalysisContext.wsd`.
