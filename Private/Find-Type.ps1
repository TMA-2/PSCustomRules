function Find-Type {
    [CmdletBinding(DefaultParameterSetName = 'Predicate')]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline
        )]
        [string]
        $TypeName,

        [Parameter(
            Position = 1,
            ValueFromPipeline,
            ParameterSetName = 'Predicate'
        )]
        [scriptblock]
        $Predicate,

        [Parameter(
            Position = 1,
            ParameterSetName = 'Exact'
        )]
        [switch]
        $Exact
    )

    process {
        <# GetTypes().Where({
            $_.IsPublic
            -and
            (
                $_.FullName -eq $TypeName
                -or
                $_.FullName -match "[\w.]+\.${TypeName}$"
                -or
                (
                    $_.Name -eq $TypeName
                    -and
                    $_.Namespace -eq 'System'
                )
            )
            })
        #>
        try {
            $AllAssemblies = [appdomain]::CurrentDomain.GetAssemblies()

            if ($Exact) {
                # Try a direct search for the type name
                $Type = [type]::GetType($TypeName, $false, $true)
                if (-not $Type) {
                    # Look for the type name in loaded assemblies
                    foreach ($assembly in $AllAssemblies) {
                        $Type = $assembly.GetType($TypeName, $false, $true)
                        if ($Type) {
                            break
                        }
                    }
                }
            }
            elseif($Predicate) {
                # Look for the type name using the provided predicate scriptblock
                $Type = $AllAssemblies.GetTypes() | Where-Object -FilterScript $Predicate
            }
            else {
                # Look for the type name (fuzzy search) in loaded assemblies
                $Type = $AllAssemblies.GetTypes() | Where-Object -FilterScript {
                    $_.IsPublic -and
                    (
                        $_.FullName -like $TypeName -or
                        $_.FullName -match "[\w.]+\.${TypeName}$"
                    )
                }
            }

            if (-not $Type) {
                Write-Verbose "Type '$TypeName' not found."
                return $null
            }

            return $Type
        }
        catch {
            $Err = $_
            Write-Error "Error finding type '$TypeName': $($Err.Exception.Message)"
        }
    }
}
