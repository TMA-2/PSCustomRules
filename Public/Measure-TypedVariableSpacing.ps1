#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
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
    [OutputType([DiagnosticRecord])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst
    )

    $violations = $ScriptBlockAst.FindAll({
            param($ast)
            # Find parameter declarations and variable assignments with type constraints
            ($ast -is [ParameterAst] -and $ast.StaticType) -or
            ($ast -is [AssignmentStatementAst] -and
            $ast.Left -is [ConvertExpressionAst])
        }, $true)

    foreach ($violation in $violations) {
        $extent = $violation.Extent
        $text = $extent.Text

        # Match type constraint without space: [string]$var
        if ($text -match '(\[[^\]]+\])(\${?\w+)' -and $text -notmatch '(\[[^\]]+\])\s+(\${?\w+)') {
            $correctedText = $text -replace '(?<type>\[[^\]]+\])(?<var>\$(?<bkt>{)?(?<scope>[a-z]+:)?[\w\(\)]+(?(bkt)}))', '${type} ${var}'

            [string]$optionalDescription = 'Add space between type constraint and variable'

            $suggestedCorrection = [CorrectionExtent]::new(
                $extent.StartLineNumber,
                $extent.EndLineNumber,
                $extent.StartColumnNumber,
                $extent.EndColumnNumber,
                $correctedText,
                $extent.File,
                $optionalDescription
            )

            [DiagnosticRecord]@{
                Message              = 'Add space between type constraint and variable name'
                Extent               = $extent
                RuleName             = 'PSTypedVariableSpacing'
                Severity             = 'Information'
                SuggestedCorrections = @($suggestedCorrection)
            }
        }
    }
}
