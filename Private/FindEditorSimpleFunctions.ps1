using namespace System.Management.Automation.Language

function findEditorSimpleFunctions {
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
        # Find simple functions in editorcontext using Find-Ast
        try {
            $SimpleFunctions = $ScriptBlockAst.FindAll({
                    param($ast)
                    $ast -is [FunctionDefinitionAst] -and
                    # exclude Class ctors/methods
                    $ast.Parent -isnot [FunctionMemberAst] -and
                    $ast.Parent -isnot [TypeDefinitionAst] -and
                    -not $ast.Body.ParamBlock -and
                    -not $ast.IsFilter -and
                    -not $ast.IsWorkflow
                }, $true)
        }
        catch {
            $Err = $_
            throw "Couldn't parse passed ScriptBlockAst > $($Err.Exception.Message)"
        }

        if (-not $SimpleFunctions) {
            Write-Verbose "Couldn't find any simple functions!"
            return
        }

        foreach ($FunctionDef in $SimpleFunctions) {
            # Parse scope and name from function name
            $FuncName = $FunctionDef.Name
            $Scope = $null
            $Name = $FuncName

            if ($FuncName -match '^(?:(?<scope>local|global|script|private):)(?<name>.*)') {
                $Scope = $Matches['scope'].TrimEnd(':')
                $Name = $Matches['name']
            }

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
            }
        }
    }
} # findEditorSimpleFunctions
