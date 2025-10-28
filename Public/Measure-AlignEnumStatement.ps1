#Requires -Version 5.0

using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic

function Measure-AlignEnumStatement {
    <#
    .SYNOPSIS
        Rule for PSScriptAnalyzer that aligns enum definitions.
    .DESCRIPTION
        This rule analyzes PowerShell enum definitions to ensure that assignment statements
        within the enum are aligned for better readability, similar to PSAlignAssignmentStatement.
        If misalignments are found, it suggests corrections to align the assignment operators.
    .PARAMETER ScriptBlockAst
        The script block AST to analyze.
        This parameter is automatically provided by PSScriptAnalyzer.
    .OUTPUTS
        List[DiagnosticRecord]
        A list of DiagnosticRecord objects indicating any alignment issues found in enum definitions, as well as suggested corrections.
    .EXAMPLE
        Measure-AlignEnumStatement -ScriptBlockAst $scriptBlockAst

        If enums are passed in the scriptblock, DiagnosticRecords are returned with suggested corrections to align them.
    .NOTES
        This rule is intended for use with the PSScriptAnalyzer module, and while it will surface diagnostic
        records and corrections if passed in valid ASTs, it is not designed to be run directly by end users.
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
                    $ast -is [TypeDefinitionAst] -and
                    $ast.IsEnum
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for commands > $($Err.Exception.Message)"
        }

        try {
            foreach ($Violation in $Violations) {
                <# Parsing logic
                - look for Enum TypeDefinitionAst
                - enumerate .Members
                    .Name = .InitialValue.Value
                - Find longest Name length
                - Align all InitialValue.Value to that length + 1 space
                - If the final text != original text, create DiagnosticRecord with suggested correction
                    - Set extent to the equal sign like PSAlignAssignmentStatement
                #>
                # [string]$file = $MyInvocation.MyCommand.Definition

                $suggestedCorrections = [Collection[CorrectionExtent]]::new()
                $correctedLines = @()

                $initialIndent = ' ' * ($Violation.Extent.StartColumnNumber - 1)

                $attributes = $Violation.Attributes
                if ($attributes) {
                    Write-Verbose "Enum has attributes; preserving in correction."
                    # $correctedLines += $attribute.Extent.Text
                }

                $correctedLines += "{0}enum {1} {{" -f $initialIndent, $Violation.Name

                $EnumMembers = $Violation.Members
                $MaxNameLength = $EnumMembers | ForEach-Object { $_.Name.Length } | Sort-Object | Select-Object -Last 1

                foreach ($member in $EnumMembers) {
                    $indent = ' ' * ($member.Extent.StartColumnNumber - 1)
                    $name = $member.Name
                    if ($null -ne $member.InitialValue) {
                        $value = $member.InitialValue.Extent.Text

                        $spaces = ' ' * ($MaxNameLength - $name.Length)

                        $correctedLine = '{0}{1}{2} = {3}' -f $indent, $name, $spaces, $value
                        $correctedLines += $correctedLine
                    }
                    else {
                        # No initial value; just use the name
                        $correctedLines += '{0}{1}' -f $indent, $name
                    }
                }

                $correctedLines += "}"

                $correctedLinesJoined = $correctedLines -join [Environment]::NewLine

                if ($correctedLinesJoined -eq $Violation.Extent.Text) {
                    continue
                }

                $StartLine = $Violation.Extent.StartLineNumber
                if ($attributes) {
                    $StartLine += $attributes.Count
                }

                $ExtentSplat = @{
                    Extent          = $Violation.Extent
                    StartLineNumber = $StartLine
                    EndLineNumber   = $StartLine
                    EndColumn       = $Violation.Extent.StartColumnNumber + $correctedLines[0].Length
                }

                $diagnosticExtent = New-ScriptExtent @ExtentSplat

                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $StartLine,
                        $Violation.Extent.EndLineNumber,
                        $Violation.Extent.StartColumnNumber,
                        $Violation.Extent.EndColumnNumber,
                        $correctedLinesJoined,
                        $Violation.Extent.File,
                        'Assignment statements in enum are not aligned.'
                    ))

                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        'Assignment statements in enum definitions should be aligned for better readability.',
                        $diagnosticExtent,
                        'PSAlignEnumStatement',
                        [DiagnosticSeverity]::Information,
                        $Violation.Extent.File,
                        'PSAlignEnumStatement',
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
