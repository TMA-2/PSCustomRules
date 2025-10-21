# TODO

## General
- [ ] Figure out what causes duplicate entries (and fix)
- [x] Optionally, add a command to VSCodeProfile to accomplish this (or only execute custom rules)
- [ ] See how [PSUseCorrectCasing](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseCorrectCasing.cs) is accomplished?

## Suggested Rules
- Refer to [Obsidian PSSA issue list](obsidian://open?vault=Obsidian&file=Development%2FGithub%20Issues%2FPSScriptAnalyzer%20Issue)
- Refer to [PSSA Repo][PSSARepo]

### PSCheckParamBlockParem
- [x] Add rule to insert a space between param and opening parenthesis
- [ ] Open issue with [PSSA Repo][PSSAIssues] to include as part of **PSUseConsistentWhitespace**

### PSAvoidSimpleFunctions
- [x] Add rule to convert simple functions to advanced -- using the existing conversion functions in VSCodeProfile

### PSCheckKeywordSpacing
- [ ] Add rule to insert a space around keywords not currently working with PSSA
- [ ] param (expand from `Measure-CheckParamBlockParen`)
- [ ] separate until and while from braces and parentheses
- [ ] Open issue with [PSSA Repo][PSSAIssues] to modify PSPlace
- DEP: simple function definition, e.g. `function MyFunc($param1)` to `function MyFunc ($param1)`
- DEP: class constructor, e.g. `MyClass() {}` to `MyClass () {}`
- DEP: class method definition, e.g. `[void] MyMethod() {}` to `[void] MyMethod () {}`

### PSUseConsistentWhitespace.CheckOperator
- [ ] Add rule to separate unary operators: [PSSA Issue](https://github.com/PowerShell/PSScriptAnalyzer/issues/2095)
- [ ] Current rule misses unary operators, e.g. `-not$true`, `-bnot1`, `-join$MyVar`

### PSAvoidUnnecessarySubexpression
- [ ] Add rule to remove subexpressions surrounding simple variables inside expandable strings
  - [ ] Before: `"Status: $($Status)"`
  - [ ] After: `"Status: $Status"`
- [ ] Add rule for implicit Parameter attributes with corrections that remove `=$True`, i.e. `[Parameter(Mandatory=$True)]` to `[Parameter(Mandatory)]`.

### PSUseQuotedAssignmentKeys
- [ ] Add rule for hashtables with corrections that surround key names with quotes.

### PSAvoidConsecutiveEmptyLines
- [ ] Add rule to remove duplicate newlines, i.e. `$FileText -replace '((?:\r?\n){2})([ \t]*(?:\r?\n))+', '$1'`

### PSEscapeInlineVariables
- [ ] Add rule to surround variables within expandable strings next to colons (other chars?) with curly braces
- [ ] Also find instances of variables next to escape characters to convert: `"$ProcessName``:`
- [ ] Perhaps parse the list of defined variables to detect if any are next to alphanumeric characters
- [ ] `"$ProcessName: OK"` to `"${ProcessName}: OK"`

## Private

### findEditorSimpleFunctions
- [x] Working thus far...

### Find-Constructor
- [ ] Decide how this will be used
- [ ] Maybe pass `Find-Type` to `Find-Constructor`?
- [ ] Verify it works independently (Add Pester test)

### Find-Type
- [ ] Decide how this will be used
- [ ] Maybe pass it to `Find-Constructor`?
- [ ] Verify it works independently (Add Pester test)

### Find-Token
- [ ] Verify it works independently (Add Pester test)
- [x] Used w/ [Measure-AvoidLongTypeNames](#measure-avoidlongtypenames)

## Public

### Measure-AvoidLongTypeNames
- [x] Get rule working
- [x] Get corrections working
- [ ] Get settings working
- [ ] Add separate `using namespace` corrections to long parameterized types, e.g. `[System.Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]`
  - [ ] option 1: Keep it as a separate correction
  - [ ] option 2: Iterate over `$ast.TypeName.GenericArguments` to add a multi-line correction along with the main type
- [x] Fix issue with `using namespace` correction extents inserting in the middle of existing entries:
- [x] Fix issue with parameterized types correcting to the class & number of params: `List``1[DiagnosticRecord]`
- [x] Test with parameterized types, e.g. `[System.Collections.Generic.List[string]]`
- [x] Fix issue with multi-param types not correcting
  - [x] Check for `$ast.TypeName.GenericArguments` (`Language.TypeName`) and split into `TypeName.TypeName.Name` and `TypeName.GenericArguments.Name`
  - [x] Use `$ast.TypeName.GenericArguments.GetReflectionType()` for full `[type]`
- [x] Fix issue with class correction losing the square brackets
- [x] Fix issue where new `using namespace` corrections insert text prior to `using namespace` blocks instead of after
- [x] Fix issue with existing `using namespace` entries not being detected to prevent duplicate corrections
- [x] Add more error handling around AST traversal
- DEP: Possibly combine corrections, if possible? Probably not because they each have an extent

### Measure-AvoidSimpleFunctions
- [x] Get rule working
- [x] Get corrections working
- [ ] Get settings working
  - [ ] Test `-AddHelp` setting
- [ ] Respect indentation for inline functions
- [x] Modify rule to exclude filters, workflows, and class ctors/methods
  - [x] Check that the Parent AST isn't a `FunctionMemberAst` or `TypeDefinitionAst`
  - [x] Check that the `IsFilter` and `IsWorkflow` properties are false
- [x] Fix extent marking everything *but* the definition...
- [x] Fix issue with overwriting function content
- [x] Fix *new* issue with inserting the advanced function prior to the existing definition, replacing 'f' in function...
- [x] Fix issue with closing brace

### Measure-UseConsistentWhitespaceEx
- [ ] Build out and test
- [ ] Catch keywords and operators that PSSA misses:
  - [ ] -not, -bnot
  - [ ] -join (when preceding)
  - [ ] until - `}until(` both brace and paren (PSUseConsistentWhitespace.CheckOpenBrace & CheckOpenParen)
  - [ ] while - `}while (` just paren, (PSUseConsistentWhitespace.CheckOpenBrace)
  - [ ] param
  - [ ] (maybe) class constructor and method `[void] MyMethod($string) {}`
  - [ ] (maybe) inline function definition `function MyFunc($string) {}`
- [ ] Merge CheckParamBlockParen with this when done

### Measure-CheckParamBlockParen
- [x] Get rule working
- [x] Get corrections working
- [x] Fix extent highlighting the full param block
- [x] Fix extent not highlighting `param\n    (`
- [x] Fix correction on `param\n    (`: it inserts an extra paranthesis, e.g. `param (    (`

### Measure-TypedVariableSpacing
- [x] Get rule working
- [x] Get corrections working
- [x] Add more error handling around AST traversal
- [x] Fix extent to only highlight the type and variable
- [ ] See if it can be added as a rule setting for [PSUseConsistentWhitespace](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseConsistentWhitespace.cs)
  - [ ] Maybe `CheckTypedVariable`?

### Measure-UseStaticConstructor
- [x] Get rule working
- [x] Get corrections working
- [ ] Support -Property hashtable arguments
- [ ] If `-ArgumentList` is an array, correctly pass individual elements
- [ ] Fix `-ArgumentList` not converting
- [ ] Fix existing `using namespace` references with only one correction
- [ ] Verify that the type has a `new()` constructor before identifying it as an issue
  - [ ] Use `Find-Constructor` function for this

<!-- References -->
[PSSARepo]: https://github.com/PowerShell/PSScriptAnalyzer
[PSSAIssues]: https://github.com/PowerShell/PSScriptAnalyzer/issues
