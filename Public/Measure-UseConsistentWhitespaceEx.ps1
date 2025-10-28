#Requires -Version 5.0

using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic

# PSUseConsistentWhitespaceEx
function Measure-UseConsistentWhitespaceEx {
    [CmdletBinding()]
    [OutputType([List[DiagnosticRecord]])]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst]
        $ScriptBlockAst
    )

    begin {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()
    }

    process {
        try {
            $Violations = $ScriptBlockAst.FindAll({
                    param ($ast)
                    # AST Predicate
                    $ast -is [WhileStatementAst] -or
                    $ast -is [DoUntilStatementAst] -or
                    $ast -is [DoWhileStatementAst] -or
                    ($ast -is [UnaryExpressionAst] -and $ast.TokenKind -in @('Not', 'Bnot', 'Join')) -or
                    $ast -is [ParamBlockAst]
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for commands > $($Err.Exception.Message)"
        }

        try {
            foreach ($Violation in $Violations) {
                <# Parsing logic
                - look for UnaryExpression
                    - TokenKind = Not, Bnot, Join
                - look for param() blocks
                - look for WhileStatement: while(){}
                - look for DoWhileStatement: do{}while()
                - look for DoUntilStatement: do{}until()
                1. separate with spaces
                #>

                $suggestedCorrections = [Collection[CorrectionExtent]]::new()

                [string]$correction = '} <keyword> ('
                [string]$optionalDescription = '<keyword> will be surrounded by spaces.'

                [string]$file = $MyInvocation.MyCommand.Definition
                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $Violation.Extent.StartLineNumber,
                        $Violation.Extent.EndLineNumber,
                        $Violation.Extent.StartColumnNumber,
                        $Violation.Extent.EndColumnNumber,
                        $correction,
                        $file,
                        $optionalDescription
                    ))

                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        'The keyword <keyword> should be surrounded by spaces.',
                        $commandAst.Extent,
                        'PSCheckKeywordSpacing',
                        [DiagnosticSeverity]::Information,
                        $null,
                        'PSCheckKeywordSpacing',
                        $suggestedCorrections
                    ))
            }

            $DiagnosticRecords
        }
        catch {
            $Err = $_
            $PSCmdlet.ThrowTerminatingError($Err)
        }
    }
}
