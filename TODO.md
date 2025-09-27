# TODO

## General
- [ ] Add rule for implicit Parameter attributes with corrections that remove `=$True`, i.e. `[Parameter(Mandatory=$True)]` to `[Parameter(Mandatory)]`.
- [ ] Add rule for hashtables with corrections that surround key names with quotes.
- [ ] Add rule to remove duplicate newlines, i.e. `$FileText -replace '((?:\r?\n){2})([ \t]*(?:\r?\n))+', '$1'`
  - [ ] Optionally, add a command to VSCodeProfile to accomplish this
- [ ] See how PSUseCorrectCasing is accomplished?

## Measure-TypedVariableSpacing
- [ ] Verify the rule works. Obviously

## Measure-NewObject
- [ ] Verify that the type has a new() constructor before identifying it as an issue

## Measure-LongTypeNames
- [ ] Test with paramterized types, e.g. `[System.Collections.Generic.List[string]]`
