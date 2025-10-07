#Requires -Version 5.0

using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic

# $testast = {New-Object 'System.IO.FileInfo' '.\.editorconfig'}
# $SBResults.BoundParameters.TypeName
#   Parameter = ParameterMetadata
#   Name = Value = 'System.IO.FileInfo'

# PSUseStaticConstructor
function Measure-UseStaticConstructor {
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
        # this should not match
        $TestComObj = New-Object -ComObject Wscript.Shell
    }

    process {
        # this won't match yet as parameterized types aren't found
        $DiagnosticRecords = New-Object List[DiagnosticRecord]
        # this should match, though
        $TestObject = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList 'C:\windows'
        $TestObject = $null

        # StaticParameterBinder helps us to find the TypeName argument
        # $spBinder = [StaticParameterBinder]

        try {
            $CommandAsts = $ScriptBlockAst.FindAll({
                    param($ast)
                    $ast -is [CommandAst] -and $ast.GetCommandName() -eq 'New-Object'
                }, $true)

            # Checks New-Object without ComObject parameter command only.
            # if ($CommandAst -and $CommandAst.GetCommandName() -ne 'New-Object') {
            #     return
            # }
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for commands > $($Err.Exception.Message)"
        }

        try {
            # $Corrections = [Collection[CorrectionExtent]]::new()

            foreach ($CommandAst in $CommandAsts) {
                [StaticBindingResult]$sbResults = [StaticParameterBinder]::BindCommand($CommandAst, $true)
                if ($sbResults.BoundParameters.ContainsKey('ComObject')) {
                    # we can't do anything to convert ComObject creation, so continue
                    continue
                }
                # get typename parameter
                if ($sbResults.BoundParameters.ContainsKey('TypeName')) {
                    $TypeName = $sbResults.BoundParameters['TypeName'].ConstantValue
                }
                # get argument list parameter
                if ($sbResults.BoundParameters.ContainsKey('ArgumentList')) {
                    $ArgumentList = $sbResults.BoundParameters['ArgumentList'].Value.Extent.Text
                    $ArgumentType = $sbResults.BoundParameters['ArgumentList'].Value.StaticType
                }
                if ($TypeName) {
                    # Find full type name
                    $FullType = [appdomain]::CurrentDomain.GetAssemblies().GetTypes().Where({ $_.IsPublic -and ($_.FullName -eq $TypeName -or $_.FullName -match "[\w.]+\.${TypeName}$" -or ($_.Name -eq $TypeName -and $_.Namespace -eq 'System')) })

                    if (-not $FullType) {
                        Write-Verbose "Type $TypeName not found in loaded assemblies."
                        continue
                    }

                    # Find constructors
                    $TypeCtors = $FullType.GetConstructors()
                    if ($TypeCtors.Count -eq 0) {
                        Write-Verbose "No public constructors found for type $TypeName"
                        return
                    }
                    else {
                        $TypeCtors = $FullType::new.OverloadDefinitions
                    }

                    if ($ArgumentList) {
                        [string]$correction = "[$TypeName]::new($ArgumentList)"
                    }
                    else {
                        [string]$correction = "[$TypeName]::new()"
                    }

                    $suggestedCorrections = [Collection[CorrectionExtent]]::new()

                    [string]$file = $MyInvocation.MyCommand.Definition
                    [string]$optionalDescription = 'Replace New-Object with static New constructor'
                    $suggestedCorrections.Add([CorrectionExtent]::new(
                            $CommandAst.Extent.StartLineNumber,
                            $CommandAst.Extent.EndLineNumber,
                            $CommandAst.Extent.StartColumnNumber,
                            $CommandAst.Extent.EndColumnNumber,
                            $correction,
                            $file,
                            $optionalDescription
                        ))
                    # $suggestedCorrections = New-Object System.Collections.ObjectModel.Collection[$($objParams.TypeName)]
                    # $suggestedCorrections.add($correctionExtent) | Out-Null

                    $result = [DiagnosticRecord]::new(
                        'Use static New constructor instead of New-Object cmdlet to create objects.',
                        $commandAst.Extent,
                        'PSUseStaticConstructor',
                        [DiagnosticSeverity]::Information,
                        $null,
                        'PSUseStaticConstructor',
                        $suggestedCorrections
                    )
                }
                else {
                    # $sbResult.BoundParameters["TypeName"].Value is a CommandElementAst, so we can return an extent.
                    # $result = New-Object -Typename "DiagnosticRecord" -ArgumentList $Messages.MeasureComObject,$sbResult.BoundParameters["ComObject"].Value.Extent,$PSCmdlet.MyInvocation.InvocationName,Warning,$null
                    $result = [DiagnosticRecord]::new(
                        'Use static New constructor instead of New-Object cmdlet to create objects.',
                        $CommandAst.Extent,
                        'PSUseStaticConstructor',
                        [DiagnosticSeverity]::Information,
                        $null
                    )
                }
                $DiagnosticRecords.Add($result)
            }

            $DiagnosticRecords
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) building DiagnosticRecord > $($Err.Exception.Message)"
            # $PSCmdlet.ThrowTerminatingError($Err)
        }
    }

    end {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($TestComObj) | Out-Null
    }
}
