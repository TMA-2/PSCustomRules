# PSCustomRules.psm1
#Requires -Version 5.1
#Requires -Modules PSScriptAnalyzer

using namespace System
using namespace System.Diagnostics.CodeAnalysis
# using module Public\Measure-NewObject.psm1
# using module Public\Measure-LongTypeNames.psm1
# using module Public\Measure-TypedVariableSpacing.psm1

# Get script files
$PrivateScripts = gci "$PSScriptRoot\Private\*" -Include '*.ps1','*.psm1'
$PublicScripts = gci "$PSScriptRoot\Public\*" -Include '*.ps1','*.psm1'

# Import private functions
$PrivateScripts | ? Extension -eq '.ps1' | % {
    . $_.FullName
}
# Import public functions
$PublicScripts | ? Extension -eq '.ps1' | % {
    . $_.FullName
}
# Import private module files
$PrivateScripts | ? Extension -eq '.psm1' | % {
    ipmo $_.FullName
}
# Import public module files
$PublicScripts | ? Extension -eq '.psm1' | % {
    ipmo $_.FullName
}

$Functions = @(
    'Measure-TypedVariableSpacing'
    'Measure-LongTypeNames'
    'Measure-NewObject'
)

Export-ModuleMember -Function $Functions
