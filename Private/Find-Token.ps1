using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function Find-Token {
    <#
    .SYNOPSIS
    Finds tokens of a particular type in a string or script path.
    .DESCRIPTION
    This cmdlet contains a longer description, its purpose, common use cases, etc.
    #>
    [OutputType([Token[]])]
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(
            Position = 0,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Path'
        )]
        [string]
        $Path,

        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ParameterSetName = 'Script'
        )]
        [string]
        $Script,

        [Parameter(
            Position = 1,
            ValueFromPipeline
        )]
        [TokenKind]
        $TokenKind
    )

    begin {
        $ParamSet = $PSCmdlet.ParameterSetName
    }

    process {
        $Token = $null
        $Errors = $null
        if ($ParamSet -eq 'Path') {
            [void][Parser]::ParseFile($Path, [ref]$Token, [ref]$Errors)
        }
        elseif ($ParamSet -eq 'Script') {
            [void][Parser]::ParseInput($Script, [ref]$Token, [ref]$Errors)
        }
        $Token | ? {
            # return matching tokens
            $_.Kind -eq $TokenKind
        }
    }
}
