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
        $Path = $Extent.File,

        [Parameter(
            Position = 2,
            ValueFromPipelineByPropertyName
        )]
        [string]
        $Text = $Extent.Text,

        [Parameter(
            Position = 3,
            HelpMessage = 'The start line number (1-based).',
            ValueFromPipelineByPropertyName
        )]
        [int]
        $StartLineNumber = $Extent.StartLineNumber,

        [Parameter(
            Position = 4,
            HelpMessage = 'The start column number (1-based).',
            ValueFromPipelineByPropertyName
        )]
        [int]
        $StartColumnNumber = $Extent.StartColumnNumber,

        [Parameter(
            Position = 5,
            HelpMessage = 'The end line number (1-based).',
            ValueFromPipelineByPropertyName
        )]
        [int]
        $EndLineNumber = $Extent.EndLineNumber,

        [Parameter(
            Position = 6,
            HelpMessage = 'The end column number (1-based).',
            ValueFromPipelineByPropertyName
        )]
        [int]
        $EndColumnNumber = $Extent.EndColumnNumber
    )

    process {
        # Get the actual line text from the extent
        # For single line extents, just use the extent text
        # For multi-line, get the first and last lines
        $lines = $Text -split '\r?\n'
        $startLineText = $lines[0]
        $endLineText = $lines[-1]

        # ScriptPosition constructor: (string scriptName, int scriptLineNumber, int offsetInLine, string line)
        # offsetInLine is the column number (1-based)
        # line is the text of that specific line
        $startPosition = [ScriptPosition]::new($Path, $StartLineNumber, $StartColumnNumber, $startLineText)
        $endPosition = [ScriptPosition]::new($Path, $EndLineNumber, $EndColumnNumber, $endLineText)

        [ScriptExtent]::new($startPosition, $endPosition)
    }
}
