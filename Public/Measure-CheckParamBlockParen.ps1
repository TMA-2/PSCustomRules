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
                    # Find param blocks without proper spacing: param( or param\n(
                    # Exclude properly spaced: param (
                    if ($ast -is [ParamBlockAst]) {
                        $text = $ast.Extent.Text
                        # Match param( directly OR param with non-space whitespace before (
                        ($text -match '^param\(') -or ($text -match '^param[\r\n\t]')
                    }
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

            # Match param block without space: param( or param\n(
            if ($text -match '^param(?<space>\s*)(?<paren>\()') {
                $paramLength = 5  # "param"
                $spaceLength = $Matches['space'].Length
                $totalLength = $paramLength + $spaceLength + 1  # +1 for the (

                # Calculate the end column
                if ($spaceLength -eq 0) {
                    # Same line: param(
                    $EndLineNumber = $extent.StartLineNumber
                    $EndColumn = $extent.StartColumnNumber + $totalLength
                    $correctedText = 'param ('
                }
                else {
                    # Newline case: param\n(
                    $EndLineNumber = $extent.StartLineNumber + 1
                    $EndColumn = 2  # Just past the opening paren
                    $correctedText = 'param ('
                }

                [string]$optionalDescription = 'Add space between param and opening parenthesis'

                try {
                    $suggestedCorrections.Add([CorrectionExtent]::new(
                            $extent.StartLineNumber,
                            $EndLineNumber,
                            $extent.StartColumnNumber,
                            $EndColumn,
                            $correctedText,
                            $extent.File,
                            $optionalDescription
                        ))

                    # Create a custom extent that only highlights "param(" not the whole param block
                    $diagnosticExtent = New-ScriptExtent -Extent $extent `
                        -StartLineNumber $extent.StartLineNumber `
                        -StartColumnNumber $extent.StartColumnNumber `
                        -EndLineNumber $EndLineNumber `
                        -EndColumnNumber $EndColumn `
                        -Text $correctedText

                    $DiagnosticRecords.Add([DiagnosticRecord]::new(
                            'Add space between param keyword and open parenthesis',
                            $diagnosticExtent,
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
                } # try/catch correction/diagnostic
            } # if match
        } # foreach violation
        $DiagnosticRecords
    } # process block
} # function
