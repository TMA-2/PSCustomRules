#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

# PSCheckParamBlockParen
function Measure-CheckParamBlockParen {
    <#
    .SYNOPSIS
    Looks for parameter blocks without a space between 'param' and opening parenthesis.
    .DESCRIPTION
    Finds parameter blocks without a space between the keyword and the opening parenthesis, and corrects them by adding a space.
    .PARAMETER ScriptBlockAst
    The script block AST to analyze.
    This parameter is automatically provided by PSScriptAnalyzer.
    .EXAMPLE
    PS C:\> Measure-CheckParamBlockParen -ScriptBlockAst $scriptBlockAst

    Analyzes the provided script block AST for parameter blocks without a space between 'param' and the opening parenthesis.
    .NOTES
    Used in conjunction with PSScriptAnalyzer.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()

        try {
            $violations = $ScriptBlockAst.FindAll({
                    param ($ast)
                    # Find predicates with closed param blocks
                    $ast -is [ParamBlockAst] -and $ast.Extent.Text -match 'param\('
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing script AST > $($Err.Exception.Message)"
        }

        foreach ($violation in $violations) {
            $extent = $violation.Extent
            $text = $extent.Text

            $suggestedCorrections = [Collection[CorrectionExtent]]::new()

            # Match param block without space: param(
            [string]$correctedText = $text -replace 'param\(', 'param ('
            [string]$optionalDescription = 'Add space between param and opening parenthesis'

            try {
                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $extent.StartLineNumber,
                        $extent.StartLineNumber,
                        $extent.StartColumnNumber,
                        $extent.EndColumnNumber,
                        $correctedText,
                        $extent.File,
                        $optionalDescription
                    ))

                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        'Add space between param keyword and open parenthesis',
                        $extent,
                        'PSCheckParamBlockParen',
                        [DiagnosticSeverity]::Information,
                        $extent.File,
                        'PSCheckParamBlockParen',
                        $suggestedCorrections
                    ))
            }
            catch {
                $Err = $_
                throw "Exception $($Err.Exception.HResult) building DiagnosticRecord > $($Err.Exception.Message)"
            }
        }
        $DiagnosticRecords
    }
}
