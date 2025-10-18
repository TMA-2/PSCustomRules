@{
    # ref: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules
    IncludeRules   = @(
        'PSTypedVariableSpacing'
        'PSCheckParamBlockParen'
        'PSAvoidLongTypeNames'
        'PSAvoidSimpleFunctions'
        'PSUseStaticConstructor'
    )

    CustomRulePath = @(
        'PSCustomRules.psm1'
    )

    # IncludeDefaultRules = $true

    Rules          = @{
        PSAvoidLongTypeNames   = @{
            Enable    = $true
            MaxLength = 40
        }

        PSAvoidSimpleFunctions   = @{
            Enable    = $true
            AddHelp   = $false
        }
    }
}
