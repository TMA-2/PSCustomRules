@{
    # ref: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules
    IncludeRules   = @(
        'PSAlignEnumStatement'
        'PSAvoidLongTypeNames'
        'PSAvoidSimpleFunctions'
        'PSCheckParamBlockParen'
        'PSTypedVariableSpacing'
        'PSUseStaticConstructor'
    )

    CustomRulePath = @(
        '.\'
    )

    # IncludeDefaultRules = $true

    Rules          = @{
        PSAvoidLongTypeNames   = @{
            Enable    = $true
            MaxLength = 40
        }

        PSAvoidSimpleFunctions = @{
            Enable  = $true
            AddHelp = $false
        }
    }
}
