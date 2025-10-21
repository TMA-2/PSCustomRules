#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.ObjectModel
using namespace System.Collections.Generic
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

# PSAvoidLongTypeNames
function Measure-AvoidLongTypeNames {
    <#
    .SYNOPSIS
        Finds long type names and suggests using statements to shorten them.
    .DESCRIPTION
        This function analyzes the provided script block AST for long type names and suggests corrections that add using statements, shortening the actual reference to only the class name.
    .PARAMETER ScriptBlockAst
        The script block AST to analyze.
        This parameter is automatically provided by PSScriptAnalyzer.
    .PARAMETER Settings
        Custom settings. Supports MaxLength (int) to define what constitutes a "long" type name. Default is 30.
        This parameter is automatically provided by PSScriptAnalyzer.
    .EXAMPLE
        PS C:\> Measure-LongTypeNames -ScriptBlockAst $scriptBlockAst -Settings @{ MaxLength = 25 }
        Analyzes the provided script block AST for long type names longer than 25 characters and suggests corrections.
    .NOTES
        Used in conjunction with PSScriptAnalyzer.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [hashtable]
        $Settings
    )

    begin {
        $RuleName = 'PSAvoidLongTypeNames'
        [int]$MaxTypeNameLength = 30
        [int]$endLine = 1
        $defaultNamespaces = [string[]]@(
            'System'
            'System.Management.Automation'
        )
    }

    process {
        $DiagnosticRecords = [List[DiagnosticRecord]]::new()

        if ($Settings -and -not $Settings.ContainsKey('Enable')) {
            return
        }

        if ($Settings -and $Settings.ContainsKey('MaxLength')) {
            $MaxTypeNameLength = $Settings['MaxLength']
        }

        try {
            # Find all "requires" comment tokens and save the last line extent
            $ScriptBlockString = $ScriptBlockAst.ToString()
            $RequiresStatements = Find-Token -Script $ScriptBlockString -TokenKind 'Comment' | Where-Object Text -Match '^#requires -'
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) finding comment tokens in scriptblock > $($Err.Exception.Message)"
        }

        # if we have requires statements, set the target "using namespace" line to one after the last entry
        if ($RequiresStatements) {
            $endLine = $RequiresStatements.ForEach({$_.Extent.EndLineNumber + 1}) | Sort-Object | Select-Object -Last 1
        }

        # Alternate method
        # if($ScriptBlockAst.ScriptRequirements.IsElevationRequired) {$endLine++}
        # if($ScriptBlockAst.ScriptRequirements.RequiredPSVersion) {$endLine++}
        # if($ScriptBlockAst.ScriptRequirements.RequiredAssemblies) {$endLine++}
        # if($ScriptBlockAst.ScriptRequirements.RequiredModules) {$endLine++}
        # if($ScriptBlockAst.ScriptRequirements.RequiredPSEditions) {$endLine++}

        # SECTION: Check for existing using statements
        try {
            $existingUsings = $ScriptBlockAst.FindAll({
                    param ($ast)
                    $ast -is [UsingStatementAst] -and
                    $ast.UsingStatementKind -eq 'Namespace'
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) traversing 'using namespace' AST entries > $($Err.Exception.Message)"
        }

        # FIXME: existingNamespaceLastLine is not getting updated properly
        $existingNamespaces = $defaultNamespaces + ($existingUsings | % { $_.Name.Value }) | select -Unique
        $existingNamespaceLastLine = $existingUsings | % { $_.Extent.EndLineNumber + 1 } | Sort | select -Last 1

        if ($existingNamespaceLastLine) {
            $endLine = [Math]::Max($endLine, $existingNamespaceLastLine)
        }

        Write-Verbose "${RuleName}: Found starting using namespace line at $endLine"

        try {
            # Find type expressions
            $typeExpressions = $ScriptBlockAst.FindAll({
                    param ($ast)
                    $ast -is [TypeExpressionAst] -or
                    $ast -is [TypeConstraintAst]
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for type expressions > $($Err.Exception.Message)"
        }

        # Group by namespace to avoid conflicts
        $classNameUsage = @{}

        foreach ($typeExpr in $typeExpressions) {
            $typeFullName = $typeExpr.TypeName.Name
            $typeName = $typeExpr.TypeName.TypeName
            $typeType = $typeExpr.TypeName.GetReflectionType()
            # this only exists for parameterized types
            if ($typeName) {
                $typeNameShort = $typeName.Name.TrimStart($typeType.Namespace)
            }
            else {
                $typeNameShort = $typeType.Name
            }
            $typeArgs = $typeExpr.TypeName.GenericArguments

            $suggestedCorrections = [Collection[CorrectionExtent]]::new()

            if ($typeFullName.Length -le $MaxTypeNameLength -or -not $typeFullName.Contains('.')) {
                continue
            }

            $namespace = $typeType.Namespace
            $className = $typeType.Name

            try {
                # Check for class name conflicts
                if ($classNameUsage.ContainsKey($className) -and
                    $classNameUsage[$className].Namespace -ne $namespace) {
                    continue # Skip if class name would conflict
                }

                $classNameUsage[$className] = @{
                    Classname = $typeNameShort
                    Namespace = $namespace
                }

                $extent = $typeExpr.Extent
                $originalText = $extent.Text
                $classNameParams = ''
                if($typeArgs) {
                    $classNameParams = '['
                    $typeArgsCount = 1
                    # SECTION: Using namespace param correction
                    foreach($typeArg in $typeArgs) {
                        # original = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
                        # namespace = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
                        # name = DiagnosticRecord
                        # fullname = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
                        $typeArgOriginal = $typeArg.Name
                        $typeArgType = $typeArg.GetReflectionType()
                        $typeArgNamespace = $typeArgType.Namespace
                        $typeArgName = $typeArgType.Name
                        $typeArgFullName = $typeArgType.FullName
                        if ($typeArgName.Length -lt $typeArgOriginal.Length) {
                            # if the usage is longer than the actual type name, add the namespace to references and use the short name
                            if ($typeArgNamespace -notin $existingNamespaces -and $classNameUsage[$typeArgName].Namespace -ne $typeArgNamespace) {
                                $addedUsingNamespace = "using namespace $typeArgNamespace`n"
                                $suggestedCorrections.Add([CorrectionExtent]::new(
                                        $endLine,
                                        $endLine,
                                        1,
                                        $addedUsingNamespace.Length,
                                        $addedUsingNamespace,
                                        $extent.File,
                                        "Add '$typeArgNamespace' type parameter reference"
                                    ))
                                $existingNamespaces += $typeArgNamespace
                                $classNameUsage[$typeArgName].Classname = $typeArgName
                                $classNameUsage[$typeArgName].Namespace = $typeArgNamespace
                                # $endLine++
                                Write-Verbose "${RuleName}: Added correction 'using namespace $typeArgNamespace' for type parameter $typeArgName at $endLine"
                            }
                        }
                        # construct type param string
                        if($typeArgsCount -lt $typeArgs.Count) {
                            $classNameParams += "$typeArgName, "
                        }
                        else {
                            $classNameParams += "$typeArgName]"
                        }
                        $typeArgsCount++
                    }
                }

                # SECTION: Using namespace correction
                if ($namespace -notin $existingNamespaces) {
                    $addedUsingNamespace = "using namespace $namespace`n"
                    $suggestedCorrections.Add([CorrectionExtent]::new(
                            $endLine,
                            $endLine,
                            1,
                            $addedUsingNamespace.Length,
                            $addedUsingNamespace,
                            $extent.File,
                            "Add '$namespace' type reference"
                        ))
                    Write-Verbose "${RuleName}: Added correction 'using namespace $namespace' at $endLine"
                }

                # SECTION: Class name correction
                $correctedText = "[$($classNameUsage[$className].Classname)$classNameParams]"
                # $correctedText = $originalText -replace [regex]::Escape($typeName), $className
                $correctedLengthDifference = $correctedText.Length - $originalText.Length

                $suggestedCorrections.Add([CorrectionExtent]::new(
                        $extent.StartLineNumber,
                        $extent.EndLineNumber,
                        $extent.StartColumnNumber,
                        $extent.EndColumnNumber,
                        $correctedText,
                        $extent.File,
                        "Shorten to $correctedText for a difference of $correctedLengthDifference chars"
                    ))

                Write-Verbose "${RuleName}: Added correction '$correctedText` at line $($extent.StartLineNumber)"

                # SECTION: Diagnostic record
                $DiagnosticRecords.Add([DiagnosticRecord]::new(
                        "Long type name detected: consider shortening to $correctedText",
                        $extent,
                        'PSAvoidLongTypeNames',
                        [DiagnosticSeverity]::Information,
                        $extent.File,
                        'PSAvoidLongTypeNames',
                        $suggestedCorrections
                    ))
            }
            catch {
                $Err = $_
                throw "Exception $($Err.Exception.HResult) building DiagnosticRecord > $($Err.Exception.Message)"
            }
        }
        $DiagnosticRecords
    }
}
