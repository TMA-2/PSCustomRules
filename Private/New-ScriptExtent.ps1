using namespace System.Management.Automation.Language

function New-ScriptExtent {
    [OutputType([ScriptExtent])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline
        )]
        [IScriptExtent]
        $Extent,

        [Parameter(
            Position = 1,
            ValueFromPipelineByPropertyName
        )]
        [string]
        $Path,

        [Parameter(
            Position = 2,
            ValueFromPipelineByPropertyName
        )]
        [string]
        $Text,

        [Parameter(
            Position = 3,
            ValueFromPipelineByPropertyName
        )]
        [int]
        $StartLineNumber,

        [Parameter(
            Position = 4,
            ValueFromPipelineByPropertyName
        )]
        [int]
        $EndLineNumber
    )

    process {
        if (-not $Path) {
            $Path = $Extent.File
        }
        if (-not $Text) {
            $Text = $Extent.Text
        }
        if (-not $StartLineNumber) {
            $StartLineNumber = $Extent.StartLineNumber
        }
        if (-not $EndLineNumber) {
            $EndLineNumber = $Extent.EndLineNumber
        }

        # NOTE: subtract extent StartOffset from EndOffset to get ending offsetInLine
        $startOffset = 1
        $endOffset = $Extent.EndOffset - $Extent.StartOffset

        # file, scriptLineNumber, offsetInLine, line
        $startPosition = [ScriptPosition]::new($Path, $StartLineNumber, $startOffset, $Text)
        $endPosition = [ScriptPosition]::new($Path, $EndLineNumber, $endOffset, $Text)
        [ScriptExtent]::new($startPosition, $endPosition)
    }
}
