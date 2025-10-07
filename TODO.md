# TODO

## General
- [ ] Add rule for implicit Parameter attributes with corrections that remove `=$True`, i.e. `[Parameter(Mandatory=$True)]` to `[Parameter(Mandatory)]`.
- [ ] Add rule for hashtables with corrections that surround key names with quotes.
- [ ] Add rule to remove duplicate newlines, i.e. `$FileText -replace '((?:\r?\n){2})([ \t]*(?:\r?\n))+', '$1'`
  - [ ] Optionally, add a command to VSCodeProfile to accomplish this
- [ ] See how [PSUseCorrectCasing](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseCorrectCasing.cs) is accomplished?

## Private

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
- [ ] Used w/ [Measure-AvoidLongTypeNames](#measure-avoidlongtypenames)

## Public

### Measure-TypedVariableSpacing
- [x] Get rule working
- [ ] Get corrections working
- [ ] Fix duplicate rule listings
  - [ ] `Add space between type constraint and variable name PSScriptAnalyzer(PSTypedVariableSpacing)`
- [x] Add more error handling around AST traversal
- [ ] See if it can be added as a rule setting for [PSUseConsistentWhitespace](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Rules/UseConsistentWhitespace.cs)
  - [ ] Maybe `CheckTypedVariable`?
  - [ ] Yeah right!

### Measure-AvoidLongTypeNames
- [x] Get rule working
- [ ] Get corrections working
- [ ] Get settings working
- [x] Add more error handling around AST traversal
- [x] Test with parameterized types, e.g. `[System.Collections.Generic.List[string]]`
- [ ] Test with long parameterized types, e.g. `[System.Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]`

### Measure-UseStaticConstructor
- [ ] Get rule working
- [ ] Get corrections working
- [ ] Verify that the type has a `new()` constructor before identifying it as an issue
  - [ ] Use `Find-Constructor` function for this
