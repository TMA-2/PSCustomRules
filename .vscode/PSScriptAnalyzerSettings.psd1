@{
    IncludeRules = @(
        'PSTypedVariableSpacing'
        'PSAvoidLongTypeNames'
        'PSUseStaticConstructor'
    )

    Rules = @{
        # IncludeDefaultRules        = $true

        CustomRulePath             = @(
            '.\..\Public\Measure-LongTypeNames.psm1'
            '.\..\Public\Measure-NewObject.psm1'
            '.\..\Public\Measure-TypedVariableSpacing.psm1'
        )

        IncludeRules               = @(
            'Measure-*'
        )

        PSUseStaticConstructor = @{
            Enable = $true
        }

        PSTypedVariableSpacing     = @{
            Enable = $true
        }

        PSAvoidLongTypeNames       = @{
            Enable    = $true
            MaxLength = 30
        }
    }
}
