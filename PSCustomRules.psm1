# PSCustomRules.psm1
#Requires -Version 5.1
#Requires -Modules PSScriptAnalyzer

# Get script files
$PrivateScripts = @(gci "$PSScriptRoot\Private\*" -Include '*.ps1','*.psm1')
$PublicScripts = @(gci "$PSScriptRoot\Public\*" -Include '*.ps1','*.psm1')

$PrivateScripts | ? Name -eq 'Find-Token.ps1' | % {
    . $_.FullName
}

# Import all functions and modules
$PublicScripts | % {
    if ($_.Extension -eq '.ps1') {
        # dot-source regular scripts
        . $_.FullName
    }
    elseif ($_.Extension -eq '.psm1') {
        # import psm1 modules
        Import-Module $_.FullName
    }
}

$Functions = @(
    'Measure-TypedVariableSpacing'
    'Measure-AvoidLongTypeNames'
    'Measure-UseStaticConstructor'
)

Export-ModuleMember -Function $Functions
