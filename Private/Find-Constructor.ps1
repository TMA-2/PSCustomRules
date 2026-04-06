function Find-Constructor {
    [OutputType('pscustomobject[]')]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline
        )]
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
            Write-Verbose "Ctor Overload Params: $($CtorParams.Count)"
            $CtorParamOutput = [pscustomobject[]]@()
            $CtorParams | Sort-Object Position | ForEach-Object {
                $OverloadDisplay = "$($_.ParameterType.FullName) $($_.Name)"
                if ($_.HasDefaultValue) {
                    $OverloadDisplay += " = $(if($null -eq $_.DefaultValue) { 'null' } else { $_.DefaultValue })"
                }
                $CtorParam = [pscustomobject]@{
                    Name         = $_.Name
                    Type         = $_.ParameterType
                    Position     = $_.Position
                    Required     = -not $_.IsOptional
                    DefaultValue = $_.DefaultValue
                    Display      = $OverloadDisplay
                }
                $CtorParamOutput += $CtorParam
            }
            $CtorParamOutput
        }
    }
}
