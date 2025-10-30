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
        $CRLF = [environment]::NewLine

        function generateHelpSection {
            param (
                [Parameter()]
                [string]$Indent = '',
                [Parameter(Mandatory)]
                [string]$SectionTitle,
                [Parameter()]
                [string]$SectionValue,
                [Parameter()]
                [string]$Content
            )

            $HelpContent = '{0}.{1}' -f $Indent, $SectionTitle
            if ($SectionValue) {
                $HelpContent += " $SectionValue$CRLF"
            }
            else {
                $HelpContent += $CRLF
            }

            if ($Content) {
                $HelpContent += '{0}{2}{1}' -f $Indent, $CRLF, $Content
            }

            return $HelpContent
        }

        function generateHelpBlock {
            [CmdletBinding()]
            param (
                [string]$Indent,
                [Parameter(Mandatory)]
                [CommentHelpInfo]$HelpContent,
                [string]$InnerIndent = "$Indent      "
            )
            $HelpContentOutput = ''
            $HelpContentOutput += "$Indent<#$CRLF"
            if ($HelpContent.Synopsis) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'SYNOPSIS' -Content $HelpContent.Synopsis
            }
            if ($HelpContent.Description) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'DESCRIPTION' -Content $HelpContent.Description
            }
            $HelpContent.Parameters.GetEnumerator() | % {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle "PARAMETER" -SectionValue $_.Key -Content $_.Value
            }
            $HelpContent.Examples | % {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'EXAMPLE' -Content $_
            }
            $HelpContent.Inputs | % {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'INPUTS' -Content $_
            }
            $HelpContent.Outputs | % {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'OUTPUTS' -Content $_
            }
            if ($HelpContent.Notes) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'NOTES' -Content $HelpContent.Notes
            }
            $HelpContent.Links | % {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'LINKS' -Content $_
            }
            if ($HelpContent.Component) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'COMPONENT' -Content $HelpContent.Component
            }
            if ($HelpContent.Role) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'ROLE' -Content $HelpContent.Role
            }
            if ($HelpContent.Functionality) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'FUNCTIONALITY' -Content $HelpContent.Functionality
            }
            if ($HelpContent.ForwardHelpTargetName) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'FORWARDHELPTARGETNAME' -SectionValue $HelpContent.ForwardHelpTargetName
            }
            if ($HelpContent.ForwardHelpCategory) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'FORWARDHELPCATEGORY' -SectionValue $HelpContent.ForwardHelpCategory
            }
            if ($HelpContent.RemoteHelpRunspace) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'REMOTEHELPRUNSPACE' -SectionValue $HelpContent.RemoteHelpRunspace
            }
            if ($HelpContent.MamlHelpFile) {
                $HelpContentOutput += generateHelpSection -Indent $InnerIndent -SectionTitle 'EXTERNALHELP' -SectionValue $HelpContent.MamlHelpFile
            }
            $HelpContentOutput += "$Indent#>$CRLF"
            $HelpContentOutput
        }
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

        # SECTION: Loop through violations
        foreach($Function in $Violations) {
            $suggestedCorrections = [Collection[CorrectionExtent]]::new()

            $FunctionName = $Function.Name
            $FunctionScope = $Function.Scope
            $Indent = ' ' * ($Function.Extent.StartColumnNumber - 1)

            # Construct function definition
            if ($FunctionScope) {
                $Output = "function ${FunctionScope}:$FunctionName {$CRLF"
            }
            else {
                $Output = "function $FunctionName {$CRLF"
            }

            # region Build help content
            # Existing CBH takes precedence over generated help
            if ($Function.HelpContent) {
                $CBHelp = $true
            }
            else {
                $CBHelp = $false
            }

            $AddHelp = $AddHelp -and -not $CBHelp

            # Build comment-based help if enabled
            if ($AddHelp) {
                $FunctionExists = Get-Command $FunctionName -ea SilentlyContinue
                if ($FunctionExists) {
                    $FunctionHelp = Get-Help $FunctionName -ea SilentlyContinue
                    $CommentBasedHelp += "$Indent<#$CRLF$Indent.SYNOPSIS$CRLF$($FunctionHelp.Synopsis)$CRLF$Indent.DESCRIPTION$CRLF"
                    if ($FunctionHelp.Description) {
                        $CommentBasedHelp += "$($FunctionHelp.Description)$CRLF"
                    }
                    else {
                        $CommentBasedHelp += "Function description$CRLF"
                    }
                }
                else {
                    $CommentBasedHelp += "$Indent<#$CRLF$Indent.SYNOPSIS$CRLF$FunctionName$CRLF$Indent.DESCRIPTION$CRLF$FunctionName$CRLF"
                }
            }
            elseif($CBHelp) {
                # use existing help content
                $CBHSplit = $Function.HelpContent.GetCommentBlock().Split([environment]::NewLine)
                $CBHelpLineCount = $CBHSplit.Count
                $CBHInside = $Function.BodyExtent.Text -match '\.SYNOPSIS'
                # find length of last non-empty line
                for ($i = -1; $i -gt -$CBHSplit.Count; $i--) {
                    if ($CBHSplit[$i].Trim().Length -gt 0) {
                        $CBHelpLastCol = $CBHSplit[$i].Trim().Length
                        break
                    }
                }
                foreach ($Line in $CBHSplit) {
                    if ($Line.Trim().Length -eq 0) {
                        $CommentBasedHelp += "$Indent$CRLF"
                    }
                    else {
                        $CommentBasedHelp += "$Indent$Line$CRLF"
                    }
                }
                if ($CBHInside) {
                    $Output += $CommentBasedHelp
                }
                # re-generate dynamically
                # $CommentBasedHelp = generateHelpBlock -HelpContent $FunctionHelp -Indent $Indent
                # $Output += $CommentBasedHelp
            }
            #endregion Build help content

            $Output += "$Indent    [CmdletBinding()]$CRLF"
            $Output += "$Indent    param ($CRLF"

            $ParamCount = 1

            #region Reconstruct parameters
            foreach ($Param in $Function.Parameters) {
                $ParamName = $Param.Name
                $ParamType = "[$($Param.Type)]"
                $ParamValue = $Param.DefaultValue
                $AttribCount = 1

                # Build CBH parameters
                if ($AddHelp) {
                    $CommentBasedHelp += "$Indent.PARAMETER $ParamName$CRLF"
                    if ($FunctionExists -and $FunctionHelp) {
                        $ParamHelpInfo = $FunctionHelp.parameters.parameter | Where-Object Name -eq $ParamName
                        $ParamHelpType = $ParamHelpInfo.type.name
                        $ParamHelpDesc = $ParamHelpInfo.description.text -join "$CRLF"
                        $ParamHelpMandatory = if ($ParamHelpInfo.required -eq 'true') {'(Mandatory) '}
                        $ParamHelpDefault = $ParamHelpInfo.defaultValue
                        if($ParamHelpDefault) {
                            $CommentBasedHelp += "$ParamHelpMandatory$ParamHelpDesc$CRLF$Indent[Type] Default value: [$ParamHelpType] $ParamHelpDefault$CRLF"
                        }
                        else {
                            $CommentBasedHelp += "$ParamHelpMandatory$ParamHelpDesc$CRLF${Indent}Type: [$ParamHelpType]$CRLF"
                        }
                    }
                    elseif ($FunctionExists) {
                        $CommentBasedHelp += "Type: $ParamType."
                        if ($ParamValue) {
                            $CommentBasedHelp += " Default value: $ParamValue$CRLF"
                        }
                    }
                    $CommentBasedHelp += "${Indent}.NOTES$CRLF${Indent}Converted automatically from simple function.$CRLF${Indent}#>$CRLF"
                }

                #region Reconstruct parameter attributes
                Write-Verbose "Processing parameter $ParamName with $($Param.Attributes.Count) attributes..."
                foreach ($Attr in $Param.Attributes) {
                    $Output += "$Indent        [$($Attr.Name)($CRLF"
                    $CombinedArgs = [string[]]@()
                    $ArgsCount = 1

                    Write-Verbose "> Processing attribute $($Attr.Name) for parameter $ParamName"
                    # Reconstruct attribute arguments
                    foreach ($Attrib in $Attr.Arguments) {
                        $AttribName = $Attrib.Name
                        $AttribArgs = $Attrib.Value
                        if ($ArgsCount -lt $Attr.Arguments.Count) {
                            $Ending = ",$CRLF"
                        }
                        else {
                            $Ending = "$CRLF"
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
                        $Output += "$Indent            $JoinedArgs$CRLF"
                    }
                    $Output += "$Indent        )]$CRLF"
                    $AttribCount++
                }
                #endregion Reconstruct parameter attributes

                $Output += "$Indent        $ParamType$CRLF"
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
                    $Output += ",$CRLF$CRLF"
                }
                else {
                    $Output += "$CRLF"
                }
                $ParamCount++
            }
            #endregion Reconstruct parameters

            if ($AddHelp) {
                $Output = $CommentBasedHelp + $Output
            }

            $Output += "$Indent    )$CRLF"

            # add CBH before the function definition
            if ($CBHelp -and -not $CBHInside) {
                $Output = $CommentBasedHelp + $Output
            }

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

            # find length of last non-empty line
            <# $OutputSplit = $Output.Split($CRLF)
            for($i = -1; $i -gt -$OutputSplit.Count; $i--) {
                $OutputLine = $OutputSplit[$i].Trim()
                if ($OutputLine.Length -gt 0) {
                    $CBHelpLastCol = $OutputLine.Length
                    break
                }
            } #>

            $CorrectionStartLine = $ExtentStartLine
            $CorrectionEndLine = $BodyStartLine
            $CorrectionStartColumn = $ExtentStartColumn
            $CorrectionEndColumn = $BodyStartColumn

            if ($CBHelp) {
                # this only supports CBH at function starts; CBH at function ends are an edge case anyway
                if ($CBHInside) {
                    $CorrectionEndLine += $CBHelpLineCount
                    $CorrectionEndColumn = $CBHelpLastCol + $Indent.Length + 4
                }
                else {
                    $CorrectionStartLine -= $CBHelpLineCount
                }
            }

            Write-Verbose "Surfacing diagnostic extent from ${ExtentStartLine}:$ExtentStartColumn to ${BodyStartLine}:$BodyStartColumn"
            $RecordExtent = New-ScriptExtent -Extent $Function.Extent -StartLineNumber $ExtentStartLine -EndLineNumber $BodyStartLine -StartColumn $ExtentStartColumn -EndColumn $BodyStartColumn

            Write-Verbose "Surfacing correction extent from ${CorrectionStartLine}:$CorrectionStartColumn to ${CorrectionEndLine}:$CorrectionEndColumn"
            $suggestedCorrections.Add([CorrectionExtent]::new(
                    $CorrectionStartLine,
                    $CorrectionEndLine,
                    $CorrectionStartColumn,
                    $CorrectionEndColumn,
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
