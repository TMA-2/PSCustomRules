@{
    # ref: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules
    IncludeRules   = @(
        'Measure-AlignEnumStatement'
        'Measure-AvoidLongTypeNames'
        'Measure-AvoidOutNull'
        'Measure-AvoidSimpleFunctions'
        # 'Measure-CheckParamBlock'
        # 'Measure-TypedVariableSpacing'
        'Measure-UseConsistentWhitespaceEx' # Stopgap fix for some things PSSA doesn't handle (full or partial), such as param(), {}until(), {}while(), -join, -not, -bnot.
        'Measure-UseStaticConstructor'
    )

    CustomRulePath = @(
        '.\'
    )

    # IncludeDefaultRules = $true

    Rules          = @{
        PSAvoidLongTypeNames   = @{
            Enable    = $true
            MaxLength = 30
        }

        PSAvoidOutNull         = @{
            Enable               = $true
            PreferNullAssignment = $false
        }

        PSAvoidSimpleFunctions = @{
            Enable                 = $true
            AddHelp                = $false
            EmptyLineBetweenParams = $true
            ParamTypeOnNewLine     = $false
        }
    }
}
