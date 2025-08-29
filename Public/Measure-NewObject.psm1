#Requires -Version 5.0

using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic

# TODO: Add rule for implicit Parameter attributes with corrections that remove =$True, i.e. [Parameter(Mandatory=$True)] to [Parameter(Mandatory)].
# TODO: Add rule for hashtables with corrections that surround key names with quotes.
# TODO: Verify that the type has a new() constructor

# $testast = {New-Object 'System.IO.FileInfo' '.\.editorconfig'}
# $SBResults.BoundParameters.TypeName
#   Parameter = ParameterMetadata
#   Name = Value = 'System.IO.FileInfo'

<#
.SYNOPSIS
    Use static New constructor instead of New-Object cmdlet to create objects.
.DESCRIPTION
    Whenever available in version 5.0 or later, use the static New constructor instead of the New-Object cmdlet to create objects. The static New constructor is faster and more efficient than the New-Object cmdlet.
.EXAMPLE
    Measure-NewObject $CommandAst
.INPUTS
    [System.Management.Automation.Language.CommandAst]
.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
.LINK
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/create-custom-rule?view=ps-modules
.LINK
    https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Tests/Engine/CommunityAnalyzerRules/CommunityAnalyzerRules.psm1
.NOTES
    Reference: Who knows.
#>
function Measure-NewObject
{
    [CmdletBinding()]
    [OutputType([DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]
        $ScriptBlock
    )

    Process
    {
        $results = @()

        # The StaticParameterBinder help us to find the argument of TypeName.
        $spBinder = [StaticParameterBinder]

        $CommandAst = $ScriptBlock.Ast.FindAll({$args[0] -is [CommandAst]}, $false)

        # Checks New-Object without ComObject parameter command only.
        if ($CommandAst.GetCommandName() -ne "new-object")
        {
            return $results
        }

        try
        {
            [StaticBindingResult]$sbResults = $spBinder::BindCommand($CommandAst, $true)
            foreach ($sbResult in $sbResults)
            {
                if ($sbResults.BoundParameters.ContainsKey("ComObject"))
                {
                    # we can't do anything to convert ComObject creation, so just return
                    return $results
                }
                # get typename parameter
                if($sbResults.BoundParameters.ContainsKey("TypeName")) {
                    $TypeName = $sbResults.BoundParameters["TypeName"].Value
                }
                # get argument list parameter
                if($sbResults.BoundParameters.ContainsKey("ArgumentList")) {
                    $ArgumentList = $sbResults.BoundParameters["ArgumentList"].Value
                }
                if($TypeName) {
                    [int]$startLineNumber = $commandAst.Extent.StartLineNumber
                    [int]$endLineNumber = $commandAst.Extent.EndLineNumber
                    [int]$startColumnNumber = $commandAst.Extent.StartColumnNumber
                    [int]$endColumnNumber = $commandAst.Extent.EndColumnNumber
                    if($ArgumentList) {
                        [string]$correction = "[$TypeName]::new($ArgumentList)"
                    } else {
                        [string]$correction = "[$TypeName]::new()"
                    }
                    [string]$file = $MyInvocation.MyCommand.Definition
                    [string]$optionalDescription = 'Replace New-Object with static New constructor'
                    $correctionExtent = [CorrectionExtent]@{
                        'StartLineNumber'   = $startLineNumber
                        'EndLineNumber'     = $endLineNumber
                        'StartColumnNumber' = $startColumnNumber
                        'EndColumnNumber'   = $endColumnNumber
                        'Text'              = $correction
                        'File'              = $file
                        'Description'       = $optionalDescription
                    }
                    # $suggestedCorrections = New-Object System.Collections.ObjectModel.Collection[$($objParams.TypeName)]
                    # $suggestedCorrections.add($correctionExtent) | Out-Null
                    $suggestedCorrections = [Collection[CorrectionExtent]]::new($correctionExtent)

                    $result = [DiagnosticRecord]@{
                        'Message'              = 'Use static New constructor instead of New-Object cmdlet to create objects.'
                        'Extent'               = $commandAst.Extent
                        'RuleName'             = $PSCmdlet.MyInvocation.InvocationName
                        'Severity'             = [DiagnosticSeverity]::Information
                        'ScriptPath'           = $null
                        'RuleSuppressionID'    = 'PSUseStaticConstructor'
                        'SuggestedCorrections' = $suggestedCorrections
                    }
                }
                else {
                    # $sbResult.BoundParameters["TypeName"].Value is a CommandElementAst, so we can return an extent.
                    # $result = New-Object -Typename "DiagnosticRecord" -ArgumentList $Messages.MeasureComObject,$sbResult.BoundParameters["ComObject"].Value.Extent,$PSCmdlet.MyInvocation.InvocationName,Warning,$null
                    $result = [DiagnosticRecord]@{
                        'Message'       = 'Use static New constructor instead of New-Object cmdlet to create objects.'
                        'Extent'        = $CommandAst.Extent
                        'RuleName'      = $PSCmdlet.MyInvocation.InvocationName
                        'Severity'      = [DiagnosticSeverity]::Information
                        'ScriptPath'    = $null
                    }
                }
                $results += $result
            }

            return $results
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
