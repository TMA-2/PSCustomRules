function Find-Constructor {
    param (
        [type]
        $Type
    )

    process {
        $TypeCtors = $Type.GetConstructors()
        if ($TypeCtors.Count -eq 0) {
            Write-Verbose "No public constructors found for type $($Type.FullName)"
            return
        }

        # alt method
        # $TypeCtorDefinitions = $Type::new.OverloadDefinitions

        foreach ($TypeCtor in $TypeCtors) {
            $CtorParams = $TypeCtor.GetParameters()
            "Ctor Overload Params: $($CtorParams.Count)"
            $CtorParamOutput = [pscustomobject[]]@()
            $CtorParams | ForEach-Object {
                $CtorParam = [pscustomobject]@{
                    Name         = $_.Name
                    Type         = $_.ParameterType
                    DefaultValue = $null
                }
                if (![string]::IsNullOrEmpty($_.DefaultValue)) {
                    $CtorParam.DefaultValue = $_.DefaultValue
                }
                $CtorParamOutput += $CtorParam
            }
            $CtorParamOutput
        }
    }
}
