#Requires -Version 5.0

using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic

# PSAlignEnumStatement
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

                $startLine = $Violation.Extent.StartLineNumber

                $attributes = $Violation.Attributes
                if ($attributes) {
                    Write-Verbose "Enum has attributes; preserving in correction."
                    # adjust the extent startline to account for attributes
                    $startLine += $attributes.Count
                }

                # construct the corrected enum definition
                $correctedLines += "{0}enum {1} {{" -f $initialIndent, $Violation.Name

                # we want any inline comments in order to reconstruct them
                $violationTextTokens = $errors = $null
                $EnumAst = [Parser]::ParseInput($Violation.Extent.Text, [ref]$violationTextTokens, [ref]$errors)

                $violationTextComments = $violationTextTokens | ? Kind -eq 'Comment'

                $EnumMembers = $Violation.Members
                $MaxLength = $EnumMembers | ForEach-Object {
                    $EnumLine = $_.Extent.StartLineNumber
                    $Comment = $violationTextComments | Where-Object {
                        $_.Extent.StartLineNumber -eq $EnumLine
                    }
                    $_.Name.Length + $Comment.Extent.Text.Length
                } | Sort-Object | Select-Object -Last 1

                <# account for the enum definition and any attributes
                $lineCount = 1 + $attributes.Count

                $EnumBuilder = [List[hashtable]]::new()
                # hashtable outline
                @{
                    Name            = 'EnumValue'
                    Value           = '0x01'
                    Comment         = 'Stream Comment'
                    CommentPosition = 'Left' # Start <Member> Left = Right <Value> End
                    Length          = 29
                } #>

                # keep a running count of the longest value + inline comment
                $lineCount = 1
                $MaxLength = 0

                foreach ($member in $EnumMembers) {
                    # determine where the comment is in relation to the member and operator. If it's to the left of the operator, factor it into MaxLength
                    # $relativeLine = $member.Extent.StartLineNumber - $Violation.Extent.StartLineNumber + 2
                    # the operator isn't in AST, so we're gonna have to regex this fuck
                    # before member '<#.*#>.+(?==)'
                    # after member '<#.*#> *(?==)'
                    # else: we don't care, stick the comment at the end

                    $indent = ' ' * ($member.Extent.StartColumnNumber - 1)
                    $name = $member.Name
                    if ($null -ne $member.InitialValue) {
                        $value = $member.InitialValue.Extent.Text

                        $spaces = ' ' * ($MaxLength - $name.Length)

                        $correctedLine = '{0}{1}{2} = {3}' -f $indent, $name, $spaces, $value
                        $correctedLines += $correctedLine
                    }
                    else {
                        # No initial value; just use the name
                        $correctedLines += '{0}{1}' -f $indent, $name
                    }
                    $lineCount++
                }

                $correctedLines += "}"

                $correctedLinesJoined = $correctedLines -join [Environment]::NewLine

                # get the original text without attributes for comparison
                $violationTextSplit = $Violation.Extent.Text.Split([Environment]::NewLine)
                $violationTextNoAttributes = $violationTextSplit[$attributes.Count..$violationTextSplit.GetUpperBound(0)] -join [Environment]::NewLine

                if ($correctedLinesJoined -eq $violationTextNoAttributes) {
                    continue
                }

                $ExtentSplat = @{
                    Extent          = $Violation.Extent
                    StartLineNumber = $startLine
                    EndLineNumber   = $startLine
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
