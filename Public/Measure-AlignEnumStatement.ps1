#Requires -Version 5.0

using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic

# PSAlignEnumStatement
function Measure-AlignEnumStatement {
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

                $suggestedCorrections = [Collection[CorrectionExtent]]::new()
                # [string]$file = $MyInvocation.MyCommand.Definition

                $EnumMembers = $Violation.Members
                $MaxNameLength = $EnumMembers | ForEach-Object { $_.Name.Length } | Sort-Object | Select-Object -Last 1

                $correctedLines = @()
                $initialIndent = ' ' * ($Violation.Extent.StartColumnNumber - 1)
                $correctedLines += "{0}enum {1} {{" -f $initialIndent, $Violation.Name

                foreach ($member in $EnumMembers) {
                    $indent = ' ' * ($member.Extent.StartColumnNumber - 1)
                    $name = $member.Name
                    if ($null -ne $member.InitialValue) {
                        $value = $member.InitialValue.Value

                        $spaces = ' ' * ($MaxNameLength - $name.Length)

                        $correctedLine = '{0}{1}{2} = {3}' -f $indent, $name, $spaces, $value
                        $correctedLines += $correctedLine
                    }
                    else {
                        # No initial value; just use the name
                        $correctedLines += "$indent$name"
                    }
                }

                $correctedLines += "}"

                $correctedLinesJoined = $correctedLines -join [Environment]::NewLine

                if ($correctedLinesJoined -eq $Violation.Extent.Text) {
                    continue
                }

                $ExtentSplat = @{
                    Extent        = $Violation.Extent
                    EndLineNumber = $Violation.Extent.StartLineNumber
                    EndColumn     = $Violation.Extent.StartColumnNumber + $correctedLines[0].Length
                }
                $diagnosticExtent = New-ScriptExtent @ExtentSplat

                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $Violation.Extent.StartLineNumber,
                        $Violation.Extent.EndLineNumber,
                        $Violation.Extent.StartColumnNumber,
                        $Violation.Extent.EndColumnNumber,
                        $correctedLinesJoined,
                        $Violation.Extent.File,
                        'Assignment statements are not aligned.'
                    ))

                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        'Assignment statements in enum definitions should be aligned for better readability.',
                        $diagnosticExtent,
                        'PSAlignEnumStatement',
                        [DiagnosticSeverity]::Warning,
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
