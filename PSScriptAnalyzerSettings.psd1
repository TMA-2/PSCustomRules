@{
    # ref: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#custom-rules
    IncludeRules   = @(
        'PSTypedVariableSpacing'
        'PSAvoidLongTypeNames'
        'PSUseStaticConstructor'
    )

    CustomRulePath = @(
        'PSCustomRules.psm1'
    )

    # IncludeDefaultRules = $true

    Rules          = @{
        PSUseStaticConstructor = @{
            Enable = $true
        }

        PSTypedVariableSpacing = @{
            Enable = $true
        }

        PSAvoidLongTypeNames   = @{
            Enable    = $true
            MaxLength = 30
        }
    }
}
