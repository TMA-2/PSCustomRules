#Requires -Version 5.0

using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic

# PSAvoidOutNull
function Measure-AvoidOutNull {
    <#
    .SYNOPSIS
    Avoid using Out-Null to suppress output.
    .DESCRIPTION
    Using Out-Null to suppress output has performance overhead. Instead, assign the output to $null or cast it to [void].
    .PARAMETER ScriptBlockAst
    The ScriptBlockAst to analyze. This parameter is provided automatically by the Script Analyzer engine.
    .OUTPUTS
    A collection of DiagnosticRecord objects that represent the rule violations found.
    .EXAMPLE
    Get-Process | Out-Null
    # Suggests: $null = Get-Process
    #>
    [CmdletBinding()]
    [OutputType([List[DiagnosticRecord]])]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [hashtable]
        $Settings = @{
            Enable = $true
            PreferNullAssignment = $true
        }
    )

    begin {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()
    }

    process {
        if ($Settings.Enable -ne $true) {
            return
        }

        try {
            # CommandAst: [CommandElementAst]CommandElements[0].Value
            # Get-Process | Out-Null
            # CommandExpressionAst: [VariableExpressionAst]Expression.ToString()
            # $Services | Out-Null
            # CommandExpressionAst: [InvokeMemberExpressionAst]Expression.Extent.Value
            # [System.Diagnostics.Process]::Start('notepad.exe') | Out-Null
            $Violations = $ScriptBlockAst.FindAll({
                    param ($ast)
                    # AST Predicate
                    $ast -is [PipelineAst] -and
                    $ast.PipelineElements.Count -ge 2 -and
                    $ast.PipelineElements[-1] -is [CommandAst] -and
                    $ast.PipelineElements[-1].CommandElements[0].Value -eq 'Out-Null'
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for commands > $($Err.Exception.Message)"
        }

        try {
            foreach ($Violation in $Violations) {
                $PipelineUbound = $Violation.PipelineElements.Count - 2
                $ExtentText = $Violation.PipelineElements[0..$PipelineUbound].Extent.Text -join ' | '
                $diagnosticExtent = $Violation.PipelineElements[-1].Extent

                if ($Settings.PreferNullAssignment) {
                    $correctionText = '$null = ' + $ExtentText
                }
                elseif (-not $Settings.PreferNullAssignment) {
                    if ($Violation.PipelineElements[0] -is [CommandAst]) {
                        $correctionText = '[void](' + $ExtentText + ')'
                    }
                    else {
                        $correctionText = '[void]' + $ExtentText
                    }
                }

                $suggestedCorrections = [Collection[CorrectionExtent]]::new()

                [string]$optionalDescription = 'Assign to $null or type as [void] to avoid performance overhead'

                [string]$file = $MyInvocation.MyCommand.Definition
                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $Violation.Extent,
                        $correctionText,
                        $file,
                        $optionalDescription
                    ))

                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        'Avoid piping to Out-Null for performance reasons.',
                        $diagnosticExtent,
                        'PSAvoidOutNull',
                        [DiagnosticSeverity]::Warning,
                        $null,
                        'PSAvoidOutNull',
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
