#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

# PSTypedVariableSpacing
function Measure-TypedVariableSpacing {
    <#
    .SYNOPSIS
    Looks for typed variables without a space between the type and the variable name.
    .DESCRIPTION
    Finds typed variables without a space between the type and the variable name, and corrects them by adding a space.
    .PARAMETER ScriptBlockAst
    The script block AST to analyze.
    This parameter is automatically provided by PSScriptAnalyzer.
    .EXAMPLE
    PS C:\> Measure-TypedVariableSpacing -ScriptBlockAst $scriptBlockAst

    Analyzes the provided script block AST for typed variables without a space between the type and the variable name.
    .NOTES
    Used in conjunction with PSScriptAnalyzer.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst
    )

    begin {
        $REMatchFull = '^(?<type>\[(?<tname>[\w.]+(?:\[[\w., ]+\])?)\])(?<var>\$(?<bkt>{)?(?<scope>[a-z]+:)?(?<vname>[^}\s]+)(?(bkt)}))(?: *= *(?<value>.+))?$'
        $REMatchShort = '^(?<type>\[(?<tname>[\w.]+(?:\[[\w., ]+\])?)\])(?<var>\$(?<bkt>{)?(?<scope>[a-z]+:)?(?<vname>[^}\s]+)(?(bkt)}))(?:,| *(?==).*)$'
    }

    process {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()

        try {
            $violations = $ScriptBlockAst.FindAll({
                    param ($ast)
                    # Find parameter declarations and variable assignments with type constraints
                    ($ast -is [ParameterAst] -and $ast.Attributes.Where{$_ -is [TypeConstraintAst]}) -or
                    ($ast -is [AssignmentStatementAst] -and
                    $ast.Left -is [ConvertExpressionAst])
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

            # Match type constraint without space: [string]$var
            if ($text -match $REMatchShort) {
                $endColumn = $extent.StartColumnNumber + $Matches['type'].length + $Matches['var'].length
                $correctedText = $Matches['type'] + ' ' + $Matches['var']

                [string]$optionalDescription = 'Add space between type constraint and variable'

                try {
                    $diagnosticExtent = New-ScriptExtent -Extent $extent `
                        -StartLineNumber $extent.StartLineNumber `
                        -StartColumnNumber $extent.StartColumnNumber `
                        -EndLineNumber $extent.EndLineNumber `
                        -EndColumnNumber $endColumn `
                        -Text $correctedText

                    $suggestedCorrections.Add([CorrectionExtent]::new(
                            $extent.StartLineNumber,
                            $extent.EndLineNumber,
                            $extent.StartColumnNumber,
                            $endColumn,
                            $correctedText,
                            $extent.File,
                            $optionalDescription
                        ))

                    $DiagnosticRecords.Add([DiagnosticRecord]::new(
                            'Add space between type constraint and variable name',
                            $diagnosticExtent,
                            'PSTypedVariableSpacing',
                            [DiagnosticSeverity]::Information,
                            $extent.File,
                            'PSTypedVariableSpacing',
                            $suggestedCorrections
                        ))
                }
                catch {
                    $Err = $_
                    throw "Exception $($Err.Exception.HResult) building DiagnosticRecord > $($Err.Exception.Message)"
                }
            }
        }
        $DiagnosticRecords
    }
}
