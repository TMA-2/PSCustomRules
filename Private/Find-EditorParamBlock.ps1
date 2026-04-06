using namespace System.Management.Automation.Language

function Find-EditorParamBlock {
    <#
    .SYNOPSIS
    Gets the first selected simple function and returns a pscustomobject with its parameters and attributes.

    .DESCRIPTION
    The function retrieves all simple functions found in the passed script block AST, converts its main parameter and attribute values to a pscustomobject[], and returns.

    .PARAMETER ScriptBlockAst
    The script block AST to analyze.
    This parameter is automatically provided by PSScriptAnalyzer.

    .NOTES
    Meant to be a private helper function for Measure-AvoidSimpleFunctions.
    #>
    [CmdletBinding()]
    param (
        [Parameter(DontShow)]
        [ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        try {
            $ParamBlocks = $ScriptBlockAst.FindAll({
                param ($ast)
                if ($ast -is [ParamBlockAst]) {
                    $text = $ast.Extent.Text
                }
            }, $true)
        }
        catch {
            $Err = $_
            throw "Couldn't parse passed ScriptBlockAst > $($Err.Exception.Message)"
        }

        if (-not $ParamBlocks) {
            Write-Verbose "Couldn't find any parameter blocks!"
            return
        }

        foreach ($ParamBlock in $ParamBlocks) {


            # Process parameters
            $ParameterObjects = @()
            foreach ($Param in $FunctionDef.Parameters) {
                # Process attributes
                $AttributeObjects = @()
                foreach ($Attr in $Param.Attributes.Where({ $_ -is [AttributeAst] })) {
                    $AttributeName = $Attr.TypeName.Name
                    $AttributeArgs = @()

                    foreach ($NamedArg in $Attr.NamedArguments) {
                        if ($NamedArg.ExpressionOmitted) {
                            $AttributeArgs += [PSCustomObject]@{
                                Name  = $NamedArg.ArgumentName
                                Value = $null
                            }
                        }
                        else {
                            $AttributeArgs += [PSCustomObject]@{
                                Name  = $NamedArg.ArgumentName
                                Value = $NamedArg.Argument.Extent.Text
                            }
                        }
                    }

                    foreach ($PositionalArg in $Attr.PositionalArguments) {
                        $AttributeArgs += [PSCustomObject]@{
                            Name  = $null
                            Value = $PositionalArg.Extent.Text
                        }
                    }

                    $AttributeObjects += [PSCustomObject]@{
                        Name      = $AttributeName
                        Arguments = $AttributeArgs
                    }
                }

                # Get parameter type
                $ParamType = $null
                $TypeConstraint = $Param.Attributes.Where({ $_ -is [TypeConstraintAst] })
                if ($TypeConstraint) {
                    $ParamType = $TypeConstraint[0].TypeName.Name
                }

                # Get default value
                $DefaultValue = $null
                if ($Param.DefaultValue) {
                    $DefaultValue = $Param.DefaultValue.Extent.Text
                }

                $ParameterObjects += [PSCustomObject]@{
                    Name         = $Param.Name.VariablePath.UserPath
                    Type         = $ParamType
                    DefaultValue = $DefaultValue
                    Attributes   = $AttributeObjects
                }
            }

            # Output function object
            [PSCustomObject]@{
                Scope        = $Scope
                Name         = $Name
                Parameters   = $ParameterObjects
                BodyExtent   = $FunctionDef.Body.Extent
                Extent       = $FunctionDef.Extent
                OriginalText = $FunctionDef.Extent.Text
                HelpContent  = $FunctionDef.GetHelpContent()
            }
        }
    }
} # Find-EditorParamBlock
