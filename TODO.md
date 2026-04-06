# TODO

## General
- [ ] Get *any* settings working for custom rules
- [ ] Figure out what causes duplicate entries for the same rule violation in the VS Code problems view / quick fix
- [x] Add a command to **VSCodeProfile** to execute custom rules
- [ ] See how [PSUseCorrectCasing](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseCorrectCasing.cs) is accomplished?

## Suggested Rules
There are a number of new rules or settings for existing rules that I feel should be added or fixed.
- Refer to [Obsidian PSSA issue list](obsidian://open?vault=Obsidian&file=Development%2FGithub%20Issues%2FPSScriptAnalyzer%20Issue)
- Refer to [PSSA Repo][PSSARepo]

### PSUseConsistentWhitespace
Essentially, fix or add the following:
- [Unary operators](#checkoperator)
- [Certain keywords (i.e. until, param)](#checkopenparen)
- [Certain keywords (i.e. while, until)](#checkclosebrace)
- Param block formatting
  - [CheckParamBlockNewlines](#checkparamblocknewlines)
  - [CheckTypedParameters](#checktypedparameters)

#### CheckParamBlockNewlines
Format param blocks with consistent indentation and line breaks, including attributes
- [ ] Include setting for separating parameters with two line breaks

#### CheckTypedParameters
Place type declarations on parameters with consistent spacing, using one of three values.
- [ ] Include setting for separating parameters and their types
  - NoSpace: `[type]$param` (default behavior)
  - OneSpace: `[type] $param`
  - NewLine: `[type]\n$param`

#### CheckOpenParen
Handle `param` and `until` keywords
- [ ] Open issue with [PSSA Repo][PSSAIssues]
- [ ] It would likely be simple enough to modify and submit a PR: [UseConsistentWhitespace Source](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseConsistentWhitespace.cs)
- [ ] The `openParenKeywordAllowList` property would just need `TokenKind.Param` and `TokenKind.Until` added.

#### CheckOperator
Current rule misses unary operators, i.e. `-not`, `-bnot`, `-join`
- [ ] Correct rule to target unary operators. A [PSScriptAnalyzer issue][PSSAUnaryIssue] has been opened.

#### CheckCloseBrace
Like CheckOpenBrace, but for `do {} while ()` and `do {} until ()` statements specifically.

### PSAvoidUnnecessarySubexpression
- [ ] Add rule to remove subexpressions surrounding simple variables inside expandable strings
  - [ ] Before: `"Status: $($Status)"`
  - [ ] After: `"Status: $Status"`

### PSUseImplicitParameterAttributes
- [ ] Add rule for implicit Parameter attributes with corrections that remove `=$True`, i.e. `[Parameter(Mandatory=$True)]` to `[Parameter(Mandatory)]`.

### PSUseConsistentHashtableKeys
- [ ] Add rule for hashtables with corrections that surround all key names with quotes.

### PSAvoidConsecutiveEmptyLines
- [ ] Add rule to remove duplicate newlines, i.e. `$FileText -replace '((?:\r?\n){2})([ \t]*(?:\r?\n))+', '$1'`
- [ ] Avoid removing newlines in here-strings
- [ ] Add setting to include stream comments

### PSEscapeInlineVariables
- [ ] Add rule to surround variables within expandable strings next to colons (other chars?) with curly braces
- [ ] Also find instances of variables next to escape characters to convert: `"$ProcessName``:`
- [ ] Perhaps parse the list of defined variables to detect if any are next to alphanumeric characters
- [ ] `"$ProcessName: OK"` to `"${ProcessName}: OK"`

## Private

### Find-EditorParamBlock
- [ ] Finish and test

### Find-EditorSimpleFunction
- [ ] Test
- [ ] Offload some functionality to `Find-EditorParamBlock`

### Find-Constructor
- [ ] Decide how this will be used
- [ ] Maybe pass `Find-Type` to `Find-Constructor`?
- [x] Find examples of constructors with optional parameters
- [ ] Verify it works independently (Add Pester test)

### Find-Type
- [ ] Decide how this will be used
- [ ] Maybe pass it to `Find-Constructor`?
- [ ] Verify it works independently (Add Pester test)

### Find-Token
- [ ] Verify it works independently (Add Pester test)
- [x] Used w/ [Measure-AvoidLongTypeNames](#measure-avoidlongtypenames)

## Public

### Measure-AlignEnumStatement
- May be added via a [PSScriptAnalyzer PR][PSSAAlignEnumPR] that adds enums to PSAlignAssignmentStatement.
  - Refer to updated [AlignAssignmentStatement](https://github.com/liamjpeters/PSScriptAnalyzer/blob/AlignAssignmentStatementV2/Rules/AlignAssignmentStatement.cs#L424-L539) rule
- [x] Write function - target `TypeDefinitionAst`
- [ ] Add correction for each assignment operator similar to PSAlignAssignmentStatement, with the extent covering the operators only
- [ ] Handle comments properly
  - [ ] Only handle inline comments prior to the key or after the value for now
  - [ ] (Later) Figure out a way to determine the location of comments relative to the operator
  - Use [Test-ScriptExtent](https://github.com/PowerShell/PowerShellEditorServices/blob/main/module/docs/Test-ScriptExtent.md) to more easily find the relative location
- [x] Fix hex/binary values converting to decimal
- [x] Fix correction for FlagAttribute enums
  - [x] Extent highlights the attribute instead of the enum definition
  - [x] Correction removes the attribute
  - NOTE: AttributeAst are actually children of TypeDefinitionAst ($ast.Attributes)
- [ ] Get help from GHCP
  ```
  With this custom rule, I'm obviously trying to align enums, since PSSA's AlignAssignmentStatement rule doesn't include them (yet). the trouble I'm running into is determining where inline comments are, since even Tokens don't track the extent of the assignment operator, and since it's been a while since I've looked at this, I've totally lost the plot.
  ```

### Measure-AvoidOutNull
- [x] Add rule to replace piping cmdlets to `Out-Null` with `[void](...)` or `$null = ...`
- [x] Add `PreferNullAssignment` boolean setting to use `$null = ...` over `[void](...)`

### Measure-AvoidLongTypeNames
- [ ] Add support for attributes (`AttributeAst`) that contain a namespace and/or period (other than System)
- [ ] Use `Join-ScriptExtent` to join Requires and Using extents?
- [ ] Figure out how to handle assembly-qualified types, e.g. `[System.String, mscorlib]`

**AttributeAst properties**
E.g. `System.Diagnostics.CodeAnalysis.SuppressMessageAttribute`

- `[ITypeName] TypeName`: System.Diagnostics.CodeAnalysis.SuppressMessageAttribute
  - `[string] AssemblyName`: null if not assembly-qualified
  - `[string] FullName`: System.Diagnostics.CodeAnalysis.SuppressMessageAttribute
  - `[bool] IsArray`: False
  - `[bool] IsGeneric`: False
  - `[string] Name`: System.Diagnostics.CodeAnalysis.SuppressMessageAttribute
  - `[type] GetReflectionType()`: SuppressMessageAttribute
  - `[type] GetReflectionAttributeType()`: SuppressMessageAttribute
- `[NamedAttributeArgumentAst] NamedArguments`: ToString() = Scope='Function'
  - `[ExpressionAst] Argument`: 'Function'
    - `[Type] StaticType`: System.String
    - `[StringConstantType] StringConstantType`: SingleQuoted
    - `[string] Value`: Function
  - `[string] ArgumentName`: Scope
  - `[bool] ExpressionOmitted`: False
- `[ExpressionAst] PositionalArguments`: ToString() = 'PSUseOutputTypeCorrectly'
  - `[Type] StaticType`: System.String
  - `[StringConstantType] StringConstantType`: SingleQuoted
  - `[string] Value`: PSUseOutputTypeCorrectly

#### DiagnosticRecord
- [x] Get rule working
- [ ] Get settings working

#### CorrectionExtent
- [x] Get corrections working
- [ ] Fix issue with using corrections inserting at line 1 even though `Measure-AvoidLongTypeNames` clearly surfaces a SuggestedCorrection with the correct extent...
  - [x] Try inserting at column 1-1 (NG)
- [ ] Add separate `using namespace` corrections to long parameterized types, e.g. `[System.Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]`
  - [ ] option 1: Keep it as a separate correction
  - [ ] option 2: Iterate over `$ast.TypeName.GenericArguments` to add a multi-line correction along with the main type
- [ ] For each violation, check the number of usages and only add a diagnostic if the `using namespace ...` length is less than the total number of namespace usages (plus 1 for the ending period)
- [x] Fix issue with using corrections overwriting line 1 with or without `#requires` or `using` statements
  - [x] Insert with a prepended newline and start/end column 1
  - [x] Verify the function's correction is returning the correct extent
- [x] Handle assembly-qualified types: `[TypeName, Namespace]` by checking `$ast.TypeName.AssemblyName`
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
> [!NOTE]
> Simple function attribute arguments are in `FunctionDefinitionAst.Parameters.Attributes.Arguments`
> [!NOTE]
> Advanced function attribute arguments are in `FunctionDefinitionAst.Body.ParamBlock.Attributes`, in PositionalArguments and NamedArguments
- [x] Add rule to convert simple functions to advanced
- [x] Get rule working
- [x] Get corrections working
- [ ] Get settings working
  - [ ] Test `-AddHelp` setting
  - [ ] Add `ParamTypeOnSameLine` setting to control the placement of types relative to parameters
  - [ ] Add `NewLineBetweenParams` setting to insert a double newline between parameters
- [ ] Use rule for `VSCodeProfile\Convert-EditorFunction` instead of duplicating work
- [ ] Use original CBH text from tokens, as `GetCommentBlock()` reconstructs it
  - [ ] Surface a setting to format CBH?
- [ ] Differentiate between CBH positions
  - [x] Inside function: `Body.Extent.Text -match '\.SYNOPSIS'`
  - [ ] Figure out how to determine if it's at the function end (edge case)
- [x] Respect indentation for inline functions
- [x] Modify rule to exclude filters, workflows, and class ctors/methods
  - [x] Check that the Parent AST isn't a `FunctionMemberAst` or `TypeDefinitionAst`
  - [x] Check that the `IsFilter` and `IsWorkflow` properties are false
- [x] Fix extent marking everything *but* the definition...
- [x] Fix issue with overwriting function content
- [x] Fix *new* issue with inserting the advanced function prior to the existing definition, replacing 'f' in function...
- [x] Fix issue with closing brace

### Measure-UseConsistentWhitespaceEx
The custom rule would temporarily make up for missed keywords (while, until), unary operators, and the lack of param block formatting.
See opened [Unary Issue][PSSAUnaryIssue] and related [Unary Issue Fix][PSSAUnaryPR].
- [ ] Build out and test
- [x] Modify `Find-EditorSimpleFunction` private function to optionally find advanced functions in order to reconstruct param blocks.
  - [ ] Optionally create a new private function to look for `ParamBlockAst` and builds them out similar to the above. Then, use it in `Find-EditorSimpleFunction` to avoid code duplication.
- [ ] Add settings to insert a space around operators and keywords not currently working with PSSA
  - [ ] [CheckOperator](#checkoperator-1)
  - [ ] [CheckOpenParen](#checkopenparen)
  - [ ] [CheckCloseBrace](#checkclosebrace-1)
- [ ] Add settings to format param blocks.
  - [ ] [CheckParamBlockNewLines](#checkparamblocknewlines-1)
  - [ ] [CheckTypedParameters](#checktypedparameters-1)

#### CheckParamBlockNewLines
- [ ] Bool setting to separate parameters in param blocks with two newlines

#### CheckTypedParameters
- [ ] Enum setting dictating the spacing between types and parameters
  - NoSpace
  - Space
  - NewLine

#### CheckOperator
- [ ] Catch operators that PSSA misses with `UnaryExpressionAst`.
  - `-not`
  - `-bnot`
  - `-join`

#### CheckOpenParen
- [ ] Handle `}until(` (with `DoUntilStatementAst`)
- [ ] Handle `param()` (with `ParamBlockAst`)
  - [ ] Merge from `Measure-CheckParamBlockParen`
- [ ] Handle class constructor and method e.g. `[void] MyMethod () {}`
- [ ] Handle inline function definition `function MyFunc () {}`

#### CheckCloseBrace
Like `CheckOpenBrace`, but includes closing braces in the case of `Do{}While()` and `Do{}Until()` statements.
- [ ] Handle `}while (` (with `WhileStatementAst`, `DoWhileStatementAst`)
- [ ] Handle `}until (` (with `DoUntilStatementAst`)

### Measure-CheckParamBlockParen
- [x] Add rule to insert a space between param and opening parenthesis
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
- [ ] Make it a setting as a part of [PSUseConsistentWhitespaceEx](#measure-useconsistentwhitespaceex)
- [ ] See if it can *actually* be added as a rule setting for [PSUseConsistentWhitespace](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseConsistentWhitespace.cs)
  - [ ] Maybe `CheckTypedVariable`?

### Measure-UseStaticConstructor
- [x] Get rule working
- [x] Get corrections working
- [ ] Only highlight `New-Object` in the extent
- [x] Support `CommandElementAst`, i.e. `New-Object System.Type(arg1, arg2)`
- [ ] Support `-Property` hashtable arguments
- [x] If `-ArgumentList` is an array, correctly pass individual elements
- [x] Fix `-ArgumentList` not converting
- [ ] Fix existing `using namespace` references with only one correction
- [ ] Verify that the type has a `new()` constructor before identifying it as an issue
  - [ ] Use `Find-Constructor` function for this

#### Copilot Suggestion
✅ **Safe rewrite cases**
Offer the suggestion **only if:**

- Parameter set is:
  - positional args
  - `-ArgumentList`
- AND `-Property` is **absent**
- AND `-ComObject` is **absent**
- AND `-Credential` is **absent** (same issue)

🚫 **Do NOT offer a fix when:**

- `-Property` is present
- `-ComObject` is used
- `-Strict` combinations where ctor inference is ambiguous

For `-Property`, the **correct analyzer behavior** is:

- ✅ Flag usage
- 🚫 Do not supply a fix
- 🛈 Emit diagnostic text explaining why

Example message:

> `New-Object -Property` performs post-construction mutation and cannot be safely translated to `::new()`

<!-- References -->
[PSSARepo]: https://github.com/PowerShell/PSScriptAnalyzer
[PSSAIssues]: https://github.com/PowerShell/PSScriptAnalyzer/issues
[PSSAUnaryIssue]: https://github.com/PowerShell/PSScriptAnalyzer/issues/2095
[PSSAUnaryPR]: https://github.com/PowerShell/PSScriptAnalyzer/pull/2114
[PSSAAlignEnumPR]: https://github.com/PowerShell/PSScriptAnalyzer/pull/2132
