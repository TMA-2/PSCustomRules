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
        PSUseStaticConstructor = @{
            Enable = $true
        }

        PSTypedVariableSpacing = @{
            Enable = $true
        }

        PSCheckParamBlockParen = @{
            Enable = $true
        }

        PSAvoidLongTypeNames   = @{
            Enable    = $true
            MaxLength = 30
        }

        PSAvoidSimpleFunctions   = @{
            Enable    = $true
            AddHelp   = $false
        }
    }
}
