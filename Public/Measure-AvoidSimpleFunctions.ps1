using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

# PSAvoidSimpleFunctions
function Measure-AvoidSimpleFunctions {
    <#
    .SYNOPSIS
        Measure-AvoidSimpleFunctions looks for simple function in a given script block, and returns diagnostic records with advanced function corrections.
    .DESCRIPTION
        This function identifies a simple PowerShell function definition from a script block, extracts its parameters and attributes, and reconstructs it as an advanced function. The converted function is then provided as a suggested correction in a diagnostic record.
    .PARAMETER ScriptBlockAst
        The script block AST to analyze.
        This parameter is automatically provided by PSScriptAnalyzer.
    .PARAMETER Settings
        If specified, contains one setting (besides Enable): AddHelp, which attempts to add comment-based help to the converted function.
        If the function already exists in the session, it will try to extract existing help content.
        Otherwise, it will attempt to scaffold basic help content based on parameter names and types.
    .EXAMPLE
        Measure-AvoidSimpleFunctions -ScriptBlockAst $scriptBlockAst -Settings @{ AddHelp = $true }

        If simple functions are passed in the scriptblock, DiagnosticRecords are returned with suggested corrections to convert them to advanced functions, including comment-based help if enabled in settings.
    .NOTES
        This rule is intended for use with the PSScriptAnalyzer module, and while it will surface diagnostic
        records and corrections if passed in valid ASTs, it is not designed to be run directly by end users.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [Parameter(
            Position = 1,
            ValueFromPipeline
        )]
        [hashtable]
        $Settings
    )

    begin {
        $Output = ''
        $CommentBasedHelp = ''
        $VERBOSE = $PSBoundParameters.ContainsKey('Verbose')
    }

    process {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()

        if ($Settings -and -not $Settings['Enable']) {
            Write-Verbose "Rule is disabled in settings."
            return
        }

        $AddHelp = $false

        if ($Settings -and $Settings.ContainsKey('AddHelp')) {
            $AddHelp = $Settings['AddHelp']
        }

        # Find the simple function definitions in the passed script block AST.
        $Violations = findEditorSimpleFunctions -ScriptBlockAst $ScriptBlockAst

        if ($Violations) {
            Write-Verbose "Found simple functions '$($Violations.Count)'"
        }
        else {
            Write-Verbose "Couldn't find a simple function definition."
            return
        }


        foreach($Function in $Violations) {
            $suggestedCorrections = [Collection[CorrectionExtent]]::new()

            $FunctionName = $Function.Name
            $FunctionScope = $Function.Scope
            $Indent = ' ' * ($Function.Extent.StartColumnNumber - 1)

            # Construct function definition
            if ($FunctionScope) {
                $Output = "function ${FunctionScope}:$FunctionName {`n"
            }
            else {
                $Output = "function $FunctionName {`n"
            }

            if ($AddHelp) {
                $FunctionExists = Get-Command $FunctionName -ea SilentlyContinue
                if ($FunctionExists) {
                    $FunctionHelp = Get-Help $FunctionName -ea SilentlyContinue
                    $CommentBasedHelp += "<#`n.SYNOPSIS`n$($FunctionHelp.Synopsis)`n.DESCRIPTION`n"
                    if ($FunctionHelp.Description) {
                        $CommentBasedHelp += "$($FunctionHelp.Description)`n"
                    }
                    else {
                        $CommentBasedHelp += "Function description`n"
                    }
                }
                else {
                    $CommentBasedHelp += "<#`n.SYNOPSIS`n$FunctionName`n.DESCRIPTION`n$FunctionName`n"
                }
            }

            $Output += "$Indent    [CmdletBinding()]`n"
            $Output += "$Indent    param (`n"

            $ParamCount = 1

            #region Reconstruct parameters
            foreach ($Param in $Function.Parameters) {
                $ParamName = $Param.Name
                $ParamType = "[$($Param.Type)]"
                $ParamValue = $Param.DefaultValue
                $AttribCount = 1

                # Build CBH parameters
                if ($AddHelp) {
                    $CommentBasedHelp += ".PARAMETER $ParamName`n"
                    if ($FunctionExists -and $FunctionHelp) {
                        $ParamHelpInfo = $FunctionHelp.parameters.parameter | Where-Object Name -eq $ParamName
                        $ParamHelpType = $ParamHelpInfo.type.name
                        $ParamHelpDesc = $ParamHelpInfo.description.text -join "`n"
                        $ParamHelpMandatory = if ($ParamHelpInfo.required -eq 'true') {'(Mandatory) '}
                        $ParamHelpDefault = $ParamHelpInfo.defaultValue
                        if($ParamHelpDefault) {
                            $CommentBasedHelp += "$ParamHelpMandatory$ParamHelpDesc`n[Type] Default value: [$ParamHelpType] $ParamHelpDefault`n"
                        }
                        else {
                            $CommentBasedHelp += "$ParamHelpMandatory$ParamHelpDesc`nType: [$ParamHelpType]`n"
                        }
                    }
                    elseif ($FunctionExists) {
                        $CommentBasedHelp += "Type: $ParamType."
                        if ($ParamValue) {
                            $CommentBasedHelp += " Default value: $ParamValue`n"
                        }
                    }
                    $CommentBasedHelp += ".NOTES`nConverted automatically from simple function.`n#>`n"
                }

                #region Reconstruct parameter attributes
                Write-Verbose "Processing parameter $ParamName with $($Param.Attributes.Count) attributes..."
                foreach ($Attr in $Param.Attributes) {
                    $Output += "$Indent        [$($Attr.Name)(`n"
                    $CombinedArgs = [string[]]@()
                    $ArgsCount = 1

                    Write-Verbose "> Processing attribute $($Attr.Name) for parameter $ParamName"
                    # Reconstruct attribute arguments
                    foreach ($Attrib in $Attr.Arguments) {
                        $AttribName = $Attrib.Name
                        $AttribArgs = $Attrib.Value
                        if ($ArgsCount -lt $Attr.Arguments.Count) {
                            $Ending = ",`n"
                        }
                        else {
                            $Ending = "`n"
                        }

                        if ($AttribName) {
                            # Write-Verbose ">> Processing attribute argument $AttribName with value $AttribArgs"
                            $Output += "$Indent           $AttribName"
                            if ($AttribArgs) {
                                # Arguments with Parameter and Value
                                $Output += " = $AttribArgs$Ending"
                            }
                            else {
                                # Parameter-only arguments
                                $Output += $Ending
                            }
                        }
                        elseif (-not $AttribName -and $AttribArgs) {
                            $CombinedArgs += $AttribArgs
                            # $Output += "            $ArgValues"
                        }
                        $ArgsCount++
                    }
                    # Add value-only arguments separated by a comma
                    if ($CombinedArgs.Count -gt 0) {
                        $JoinedArgs = $CombinedArgs -join ', '
                        Write-Verbose ">> Appending attribute values $JoinedArgs"
                        $Output += "$Indent            $JoinedArgs`n"
                    }
                    $Output += "$Indent        )]`n"
                    $AttribCount++
                }
                #endregion Reconstruct parameter attributes

                $Output += "$Indent        $ParamType`n"
                if ($null -ne $ParamValue) {
                    # Add parameter default value
                    $Output += "$Indent        `$$ParamName = $ParamValue"
                }
                else {
                    # Parameter only
                    $Output += "$Indent        `$$ParamName"
                }
                if ($ParamCount -lt $Function.Parameters.Count) {
                    # Add empty line between parameters
                    $Output += ",`n`n"
                }
                else {
                    $Output += "`n"
                }
                $ParamCount++
            }
            #endregion Reconstruct parameters

            if ($AddHelp) {
                $Output = $CommentBasedHelp + $Output
            }

            $Output += "$Indent    )`n"

            # subtract function extent StartOffset from EndOffset to get ending offsetInLine
            # Create: [ScriptExtent]::new(<ScriptPosition> startPosition, <ScriptPosition> endPosition)
            <#
            $startOffsetInLine = 1
            # $endOffsetInLine = $Function.BodyExtent.StartOffset - $Function.Extent.StartOffset + 1
            # $StartPosition = [ScriptPosition]::new($Function.BodyExtent.File, $Function.BodyExtent.StartLineNumber, $startOffsetInLine, $Function.BodyExtent.Text)
            # $endPosition = [ScriptPosition]::new($Function.BodyExtent.File, $Function.BodyExtent.StartLineNumber, $endOffsetInLine, $Function.BodyExtent.Text)
            # $RecordExtent = [ScriptExtent]::new($StartPosition, $endPosition)
            #>

            $ExtentStartLine = $Function.Extent.StartLineNumber
            $BodyStartLine = $Function.BodyExtent.StartLineNumber
            $ExtentStartColumn = $Function.Extent.StartColumnNumber
            $BodyStartColumn = $Function.BodyExtent.StartColumnNumber + 1
            Write-Verbose "Converted simple function to advanced; from $($Function.OriginalText.Length) to $($Output.Length) chars"

            $RecordExtent = New-ScriptExtent -Extent $Function.Extent -StartLineNumber $ExtentStartLine -EndLineNumber $BodyStartLine -StartColumn $ExtentStartColumn -EndColumn $BodyStartColumn

            $suggestedCorrections.Add([CorrectionExtent]::new(
                    $ExtentStartLine,
                    $BodyStartLine,
                    $ExtentStartColumn,
                    $BodyStartColumn,
                    $Output,
                    $Function.Extent.File,
                    "Convert to advanced function of $($Output.Length) chars"
                ))

            $DiagnosticMessage = if ($FunctionScope) {
                "Simple function '${FunctionScope}:${FunctionName}' should be converted to an advanced function."
            }
            else {
                "Simple function '$FunctionName' should be converted to an advanced function."
            }

            $DiagnosticRecords.Add([DiagnosticRecord]::new(
                    $DiagnosticMessage,
                    $RecordExtent,
                    'PSAvoidSimpleFunctions',
                    [DiagnosticSeverity]::Warning,
                    $Function.Extent.File,
                    'PSAvoidSimpleFunctions',
                    $suggestedCorrections
                ))
        }
        $DiagnosticRecords
    }
}
