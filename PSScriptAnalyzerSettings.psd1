@{
    # ref: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules
    IncludeRules   = @(
        'Measure-AlignEnumStatement'
        'Measure-AvoidLongTypeNames'
        'Measure-AvoidSimpleFunctions'
        # 'Measure-CheckParamBlockParen'
        # 'Measure-TypedVariableSpacing'
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

        PSAvoidSimpleFunctions = @{
            Enable  = $true
            AddHelp = $false
        }
    }
}
