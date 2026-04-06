#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

# PSCheckParamBlock
function Measure-CheckParamBlock {
    <#
    .SYNOPSIS
    Looks for parameter blocks and adjusts their formatting based on a number of settings.
    .DESCRIPTION
    Finds parameter blocks that don't match formatting standards like having a line between parameters, having the type and variable on separate lines, newlines between attributes, etc.
    .PARAMETER ScriptBlockAst
    The script block AST to analyze.
    This parameter is automatically provided by PSScriptAnalyzer.
    .EXAMPLE
    PS C:\> Measure-CheckParamBlock -ScriptBlockAst $scriptBlockAst

    Analyzes the provided script block AST for parameter blocks without a space between 'param' and the opening parenthesis.
    .NOTES
    Used in conjunction with PSScriptAnalyzer.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [hashtable]
        $Settings = @{
            CheckParamWhitespace         = $true
            CheckNewlineAfterParam       = $true
            CheckSeparateTypeAndVariable = $true
            CheckSeparateAttributes      = $true
        }
    )

    begin {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()
    }

    process {
        try {
            $violations = $ScriptBlockAst.FindAll({
                    param ($ast)
                    if ($ast -is [ParamBlockAst]) {
                        $text = $ast.Extent.Text
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
                $correctedText = 'param ('

                # Calculate the end column
                if ($spaceLength -eq 0) {
                    # Same line: param(
                    $EndLineNumber = $extent.StartLineNumber
                    $EndColumn = $extent.StartColumnNumber + $totalLength
                }
                else {
                    # Newline case: param\n(
                    $EndLineNumber = $extent.StartLineNumber + 1
                    $EndColumn = $spaceLength  # Just past the opening paren
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
                            'PSCheckParamBlock',
                            [DiagnosticSeverity]::Information,
                            $extent.File,
                            'PSCheckParamBlock',
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
