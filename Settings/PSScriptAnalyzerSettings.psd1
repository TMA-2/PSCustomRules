@{
    IncludeRules = @(
        'PSTypedVariableSpacing'
        'PSAvoidLongTypeNames'
    )

    Rules = @{
        IncludeDefaultRules = $true

        PSTypedVariableSpacing = @{
            Enable = $true
        }

        PSAvoidLongTypeNames = @{
            Enable = $true
            MaxLength = 30
        }
    }
}
