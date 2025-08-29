# PSCustomRules.psm1
#Requires -Version 5.1
#Requires -Modules PSScriptAnalyzer

# Import private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*" -Include '*.ps1','*.psm1' | ForEach-Object {
    . $_.FullName
}

# Import public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*" -Include '*.ps1','*.psm1' | ForEach-Object {
    . $_.FullName
}

$Functions = @(
    'Measure-TypedVariableSpacing'
    'Measure-LongTypeNames'
    'Measure-NewObject'
)

Export-ModuleMember -Function $Functions
