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
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='Path'
            )]
        [string]
        $Path,

        [Parameter(
            ValueFromPipeline,
            ParameterSetName='Script'
            )]
        [string]
        $Script,

        [Parameter()]
        [TokenKind]
        $TokenKind
    )

    begin {
        $ParamSet = $PSCmdlet.ParameterSetName
    }

    process {
        $Token = $null
        if($ParamSet -eq 'Path') {
            [Parser]::ParseFile($Path, [ref]$Token, [ref]$null) | Out-Null
        }
        elseif($ParamSet -eq 'Script') {
            [Parser]::ParseInput($Script, [ref]$Token, [ref]$null) | Out-Null
        }
        $Token | ? {$_.Kind -eq $TokenKind}
    }
}
