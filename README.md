# README

This is a shoddy attempt to create custom PSScriptAnalyzer rules. Haven't yet made it work.

## Rules

### PSTypedVariableSpacing
Looks for typed variables and attempts to insert a space between them.
Probably ought to be part of `PSUseConsistentWhitespace` or something.
**Function:** `Measure-TypedVariableSpacing`

#### Example
```powershell
# before
[string]$Property
# after
[string] $Property
```

### PSAvoidLongTypeNames
Looks for .NET type names longer than 30 characters, although that's meant to be configurable (see below).
Attempts to offer a fix that inserts a `using namespace` reference at the top of the script, and converts the type to only the class name.
**Function:** `Measure-LongTypeNames`

**Configure:**
```powershell
@{
    Rules = @{
        PSAvoidLongTypeNames       = @{
            Enable    = $true
            MaxLength = 30
        }
    }
}
```

#### Example
*Before*
```powershell
# 48 chars
[System.Collections.Specialized.OrderedDictionary]::new()
```
*After*`
```powershell
using namespace System.Collections.Specialized

# 17 chars
[OrderedDictionary]::new()
```

### PSUseStaticConstructor
Looks for instances of `New-Object` (excepting those using `-ComObject`) and adds a fix that attempts to convert it to a `new()` constructor.
Needs work to convert `-ArgumentList` hashtable to parameters.

#### Example
```powershell
# before
$Type = New-Object 'Microsoft.Win32.Registry'
# after
$Type = [Microsoft.Win32.Registry]::new()
```

## References
- See [the official CommunityAnalyzerRules](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Tests/Engine/CommunityAnalyzerRules/CommunityAnalyzerRules.psm1)
- See [this custom rule example](https://github.com/bergmeister/PSScriptAnalyzer-VSCodeIntegration) for how to define and include custom rules in VSCode
- See [custom Indented.ScriptAnalyzerRules module](https://github.com/indented-automation/Indented.ScriptAnalyzerRules) for custom rules
- See [PSScriptAnalyzer docs on custom rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/create-custom-rule?view=ps-modules)
- See [PSScriptAnalyzer docs on using custom rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules)
