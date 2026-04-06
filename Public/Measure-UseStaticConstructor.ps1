#Requires -Version 5.0

using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.Powershell.ScriptAnalyzer.Generic

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
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()
    }

    process {
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
                if ($sbResults.BoundParameters.ContainsKey('ComObject') -or $sbResults.BoundParameters.ContainsKey('Property')) {
                    # we can't do anything to convert ComObject creation
                    # we don't handle the -Property parameter
                    continue
                }

                # get typename parameter
                if ($sbResults.BoundParameters.ContainsKey('TypeName')) {
                    $TypeName = $sbResults.BoundParameters['TypeName'].ConstantValue
                }

                # get argument list parameter
                if ($sbResults.BoundParameters.ContainsKey('ArgumentList')) {
                    $argValue = $sbResults.BoundParameters['ArgumentList'].Value

                    switch ($argValue) {
                        { $_ -is [ArrayExpressionAst] } {
                            # -ArgumentList @(a,b)
                            $elements = $argValue.SubExpression.Statements[0].PipelineElements[0].Expression.Elements

                            $ArgumentList = ($elements.ForEach{$_.Extent.Text}) -join ', '
                            break
                        }
                        { $_ -is [ArrayLiteralAst] } {
                            # -ArgumentList ,a  OR  -ArgumentList a,b
                            $ArgumentList = ($argValue.Elements.ForEach{$_.Extent.Text}) -join ', '
                            break
                        }
                        { $_ -is [ParenExpressionAst] } {
                            # -ArgumentList (a,b)
                            $elements = $argValue.Pipeline.PipelineElements[0].Expression.Elements
                            $ArgumentList = ($elements.ForEach{$_.Extent.Text}) -join ', '
                            break
                        }
                        default {
                            # -ArgumentList a
                            $ArgumentList = $argValue.Extent.Text
                        }
                    }

                    <# Old method
                    if ($argValue -is [CommandElementAst]) {
                        # alternately, just get the extent text of the entire argument list and use that as the argument list for the static constructor, since it will be the same text either way
                        # $ArgumentList = $sbResults.BoundParameters['ArgumentList'].Value.Pipeline.Extent.Text
                        $ArgumentList = [List[string]]::new()
                        $argValue.Pipeline.PipelineElements.Expression.Elements | % {
                            # can also switch based on $_.GetType() i.e. VariableExpressionAst, StringConstantExpressionAst, etc.
                            $ArgumentList.Add($_.Extent.Text)
                        }
                        $ArgumentList = $ArgumentList -join ', '
                    }
                    elseif ($argValue -is [ParenExpressionAst]) {
                        $ArgumentList = [List[string]]::new()
                        $argValue.Pipeline.PipelineElements.Expression.Elements | % {
                            $ArgumentList.Add($_.Extent.Text)
                        }
                        $ArgumentList = $ArgumentList -join ', '
                    }
                    else {
                        $ArgumentList = $argValue.SubExpression.Extent.Text
                        $ArgumentType = $argValue.StaticType
                    }
                    #>
                }

                # only highlight the command
                $NewObjectExtent = $CommandAst.CommandElements.Where({$_.Value -eq 'New-Object'}).Extent

                if ($TypeName) {
                    try {
                        # Find full type name
                        $FullType = Find-Type -TypeName $TypeName -Exact
                        # $FullType = [appdomain]::CurrentDomain.GetAssemblies().GetTypes().Where({ $_.IsPublic -and ($_.FullName -eq $TypeName -or $_.FullName -match "[\w.]+\.${TypeName}$" -or ($_.Name -eq $TypeName -and $_.Namespace -eq 'System')) })

                        if (-not $FullType) {
                            throw [TypeLoadException]::new("Type $TypeName not found in loaded assemblies.")
                        }
                    }
                    catch {
                        $Err = $_
                        throw "Exception $($Err.Exception.HResult) finding type $TypeName > $($Err.Exception.Message)"
                    }

                    try {
                        # Find constructors
                        $TypeCtors = $FullType.GetConstructors()
                        if ($TypeCtors.Count -eq 0) {
                            throw "No public constructors found for type $TypeName"
                        }
                    }
                    catch {
                        try {
                            $TypeCtors = $FullType::new.OverloadDefinitions
                        }
                        catch {
                            $Err = $_
                            throw "Couldn't get static constructor for $TypeName > $($Err.Exception.Message)"
                        }
                    }

                    if (-not $TypeCtors) {
                        Write-Verbose "No constructors found for type $TypeName"
                        return
                    }

                    if ($ArgumentList) {
                        [string]$correction = "[$TypeName]::new($ArgumentList)"
                    }
                    elseif ($TypeProperties) {
                        $props = $TypeProperties.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }
                        $propsString = $props -join '; '
                        [string]$correction = "[$TypeName]@{ $propsString }"
                    }
                    else {
                        [string]$correction = "[$TypeName]::new()"
                    }

                    $suggestedCorrections = [Collection[CorrectionExtent]]::new()

                    [string]$file = $MyInvocation.MyCommand.Definition
                    [string]$optionalDescription = "Replace 'New-Object $TypeName' with $correction"
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
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                        <#Category#>'PSUseDeclaredVarsMoreThanAssignments',<#CheckId#>$null,
                        Justification = 'Reason for suppressing'
                    )]
                    $result = [DiagnosticRecord]::new(
                        'Consider using static constructor instead of New-Object to instantiate classes.',
                        $NewObjectExtent,
                        'PSUseStaticConstructor',
                        [DiagnosticSeverity]::Information,
                        $CommandAst.Extent.File,
                        'PSUseStaticConstructor',
                        $suggestedCorrections
                    )
                }
                else {
                    # $sbResult.BoundParameters["TypeName"].Value is a CommandElementAst, so we can return an extent.
                    # $result = New-Object -Typename "DiagnosticRecord" -ArgumentList $Messages.MeasureComObject,$sbResult.BoundParameters["ComObject"].Value.Extent,$PSCmdlet.MyInvocation.InvocationName,Warning,$null
                    $result = [DiagnosticRecord]::new(
                        'Use static New constructor instead of New-Object cmdlet to create objects.',
                        $NewObjectExtent,
                        'PSUseStaticConstructor',
                        [DiagnosticSeverity]::Information,
                        $CommandAst.Extent.File
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
        # [System.Runtime.InteropServices.Marshal]::ReleaseComObject($TestComObj) | Out-Null
    }
}
