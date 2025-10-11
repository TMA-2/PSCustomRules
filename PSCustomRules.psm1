# PSCustomRules.psm1
#Requires -Version 5.1
#Requires -Modules PSScriptAnalyzer

# Get script files
$PrivateScripts = @(gci -Path "$PSScriptRoot\Private\*" -Include '*.ps1','*.psm1')
$PublicScripts = @(gci -Path "$PSScriptRoot\Public\*" -Include '*.ps1','*.psm1')

# Import all functions and modules
$PrivateScripts + $PublicScripts | % {
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
    'Measure-CheckParamBlockParen'
    'Measure-AvoidLongTypeNames'
    'Measure-UseStaticConstructor'
    'Measure-AvoidSimpleFunctions'
)

Export-ModuleMember -Function $Functions
