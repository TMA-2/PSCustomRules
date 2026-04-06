function Find-Type {
    [CmdletBinding()]
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
            # $AllAssemblies = [appdomain]::CurrentDomain.GetAssemblies().Where({ $_.FullName -notmatch '(System\.Data\.SqlClient|Azure\.Data\.Tables).*' })

            if ($Exact) {
                # Try a direct search for the type name
                $Type = [type]::GetType($TypeName, $false, $true)
                if ($Type) {
                    return $Type
                }
                else {
                    # Look for the type name in loaded assemblies
                    foreach ($assembly in [appdomain]::CurrentDomain.GetAssemblies()) {
                        $Type = $assembly.GetType($TypeName, $false, $true)
                        if ($Type) {
                            return $Type
                        }
                    }
                }
            }
            else {
                $AllTypes = foreach ($asm in [appdomain]::CurrentDomain.GetAssemblies()) {
                    try {
                        $asm.GetTypes()
                    }
                    catch [System.Reflection.ReflectionTypeLoadException] {
                        $Err = $_
                        $Err.Exception.Types | Where-Object { $_ }
                    }
                }
            }

            if ($Predicate) {
                # Look for the type name using the provided predicate scriptblock
                $AllTypes | Where-Object -FilterScript $Predicate
            }
            else {
                # Look for the type name (fuzzy search) in loaded assemblies
                $AllTypes | Where-Object -FilterScript {
                    $_.IsPublic -and
                    (
                        $_.FullName -like $TypeName -or
                        $_.FullName -match "[\w.]+\.${TypeName}$"
                    )
                }
            }

            <# if (-not $AllTypes -or $AllTypes.Count -eq 0) {
                Write-Verbose "Type '$TypeName' not found."
                return $null
            }
            return $AllTypes
            #>
        }
        catch {
            $Err = $_
            Write-Error "Error finding type '$TypeName': $($Err.Exception.Message)"
        }
    }
}
