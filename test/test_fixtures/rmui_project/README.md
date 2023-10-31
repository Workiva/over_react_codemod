A package that depends on react_material_ui, and can be used as a context root for tests that require a resolved analysis context with access to react_material_ui APIs.

This is separate from over_react_project, since react_material_ui is only required for some tests, and fetching it as a dependency requires access to a private Pub server, meaning it can't be run in GitHub Actions. 

To use, see `SharedAnalysisContext.rmui`.
