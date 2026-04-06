# README

This is an attempt to create custom PSScriptAnalyzer rules, both custom and as stopgaps for certain PSSA issues. Some progress has been made now.

## Rules

### PSAlignEnumStatement
Since PSAlignAssignmentStatement doens't include enums... here we are.

### PSAvoidOutNull
Looks for instances of `Out-Null` and offers a fix to convert them to `$null =` assignments or casts to `[void]`.

**Function:** `Measure-AvoidOutNull`

**Configure:**
```powershell
@{
    Rules = @{
        PSAvoidOutNull       = @{
            Enable               = $true
            PreferNullAssignment = $true
        }
    }
}
```

- **PreferNullAssignment** when `$true`, offers fixes that assign to `$null` instead of casting to `[void]`.

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

- **MaxLength** is the maximum length of a .NET type name before it is considered "long".

### PSAvoidSimpleFunctions
Finds simple/inline functions and converts them to advanced functions, with an optional comment-based help setting.

**Function:** `Measure-AvoidSimpleFunctions`

**Configure:**
```powershell
@{
    Rules = @{
        PSAvoidSimpleFunctions       = @{
            Enable                 = $true
            AddHelp                = $true
            ParamTypeOnNewLine     = $true
            EmptyLineBetweenParams = $true
        }
    }
}
```

- **AddHelp** will insert a basic comment-based help block if one doesn't already exist. Existing CBH is first checked and used if it exists, and if not, a new one is created from Get-Help content.
- **ParamTypeOnNewLine** will separate parameter type and name with a newline.
- **EmptyLineBetweenParams** will insert an empty line between parameters in the param block.

### PSCheckParamBlockParen
Very simple. Checks for param blocks and inserts a space, e.g. `param (`. Includes param blocks with newlines before the opening paranthesis.
In the future, this should be rolled into a PSUseConsistentWhitespaceEx rule to include keywords PSSA currently misses, like `until` and `while`.

**Function:** `Measure-CheckParamBlockParen`

### PSTypedVariableSpacing
Another simple rule. Looks for typed variables and inserts a space between them.
Probably ought to be part of `PSUseConsistentWhitespace`, but that would be a bit too complex for me.

**Function:** `Measure-TypedVariableSpacing`

#### Example
```powershell
# before
[string]$Property
# after
[string] $Property
```

### PSUseStaticConstructor
Looks for instances of `New-Object` (excepting those using `-ComObject`) and adds a correction that to converts it to a static `new()` constructor.
Needs work to better convert `-ArgumentList` parameters.

#### Example
```powershell
# before
$Registry = New-Object 'Microsoft.Win32.Registry'
# after
$Registry = [Microsoft.Win32.Registry]::new()
# before
$RegistryAccessRule = New-Object System.Security.AccessControl.RegistryAccessRule($User, $Rights, 'Allow')
# after
$RegistryAccessRule = [System.Security.AccessControl.RegistryAccessRule]::new($User, $Rights, 'Allow')
```

## Planned Rules

### PSUseConsistentWhitespaceEx
A stopgap for certain PSSA issues that as yet (1.24) haven't been fixed. This includes unary operator spacing (`-not`, `-bnot`, `-join`) and some keywords (`until`, `while`).
A PR is open for the unary operator issue, but has been sitting there without review for months now.

## References
- [The official CommunityAnalyzerRules](https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Tests/Engine/CommunityAnalyzerRules/CommunityAnalyzerRules.psm1)
- [This custom rule example](https://github.com/bergmeister/PSScriptAnalyzer-VSCodeIntegration) for how to define and include custom rules in VSCode
- [Custom Indented.ScriptAnalyzerRules module](https://github.com/indented-automation/Indented.ScriptAnalyzerRules) for custom rules
- [PSScriptAnalyzer docs on custom rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/create-custom-rule?view=ps-modules)
- [PSScriptAnalyzer docs on using custom rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules)
