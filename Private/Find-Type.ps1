function Find-Type {
    param (
        [string]
        $TypeName,

        [switch]
        $Exact
    )

    process {
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
            else {
                # Look for the type name (fuzzy search) in loaded assemblies
                $Type = $AllAssemblies.GetTypes() | Where-Object {
                    $_.IsPublic -and
                    (
                        $_.FullName -like $TypeName -or
                        $_.FullName -match "[\w.]+\.${TypeName}$" -or
                        $_.Namespace -eq 'System'
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
