#Requires -Version 5.0

using namespace System.Diagnostics.CodeAnalysis
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
        This rule is intended for use with the PSScriptAnalyzer module, and while it will surface diagnostic
        records and corrections if passed in valid ASTs, it is not designed to be run directly by end users.
    #>
    [OutputType([List[DiagnosticRecord]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [hashtable]
        $Settings = @{
            Enable    = $true
            MaxLength = 40
        }
    )

    begin {
        $RuleName = 'PSAvoidLongTypeNames'
        [int]$endLine = 1
        $defaultNamespaces = [string[]]@(
            'System'
            'System.Management.Automation'
        )
    }

    process {
        if (-not $Settings.Enable) {
            return
        }

        $MaxTypeNameLength = $Settings.MaxLength

        $DiagnosticRecords = [List[DiagnosticRecord]]::new()

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
            Write-Verbose "${RuleName}: Found $($RequiresStatements.Count) requires statement(s) prior to $endLine"
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
                    $ast -is [UsingStatementAst]
                    # $ast.UsingStatementKind -eq 'Namespace'
                }, $true)
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) traversing 'using' AST statements > $($Err.Exception.Message)"
        }

        $lineOneExtent = $ScriptBlockAst.Find({
                param ($ast)
                $ast -is [ScriptExtent] -and
                $ast.StartLineNumber -eq 1 -and
                $ast.EndLineNumber -eq 1
            }, $true)

        $existingNamespaces = $defaultNamespaces + ($existingUsings.Where({$_.UsingStatementKind -eq 'Namespace'}) | % { $_.Name.Value }) | Select-Object -Unique
        $existingUsingLastLine = $existingUsings | % { $_.Extent.EndLineNumber + 1 } | Sort-Object | Select-Object -Last 1

        if ($existingUsingLastLine) {
            $endLine = [Math]::Max($endLine, $existingUsingLastLine)
            Write-Verbose "${RuleName}: Found $($existingUsings.Count) using statement(s) up to line $endLine"
        }

        try {
            # SECTION: Find type expressions
            # TODO: Handle AttributeAst type usages, e.g. [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute()]
            # New-Object: $ast -is [CommandAst] -and $ast.GetCommandName() -eq 'New-Object'
            #   [StaticBindingResult]$sbResults = [StaticParameterBinder]::BindCommand($CommandAst, $true)
            #   $sbResults.BoundParameters['TypeName'].ConstantValue
            $typeExpressions = $ScriptBlockAst.FindAll({
                    param ($ast)
                    ($ast -is [TypeExpressionAst] -or
                    $ast -is [TypeConstraintAst]) -and
                    $ast.TypeName.Name.Contains('.') -and
                    ($ast.TypeName.FullName.Contains(',') -and $ast.TypeName.GenericArguments)
                }, $true)
            Write-Verbose "${RuleName}: Found $($typeExpressions.Count) type expressions"
        }
        catch {
            $Err = $_
            throw "Exception $($Err.Exception.HResult) parsing AST for type expressions > $($Err.Exception.Message)"
        }

        # Group by namespace to avoid conflicts
        $classNameUsage = @{}

        # SECTION: Analyze each type expression
        foreach ($typeExpr in $typeExpressions) {
            Write-Verbose "${RuleName}: Analyzing type expression $($typeExpr.Extent.Text) at line $($typeExpr.Extent.StartLineNumber)"
            $typeFullName = $typeExpr.TypeName.Name # List[string]
            $typeName = $typeExpr.TypeName.TypeName # <typename> List
            # this will return null if it's an assembly-qualified type, e.g. [System.String, mscorlib], so we need to handle that case in future
            $typeType = $typeExpr.TypeName.GetReflectionType() # <type> List`1
            $assemblyType = $typeExpr.TypeName.AssemblyName
            # this only exists for parameterized types
            if ($typeName) {
                $typeNameShort = $typeName.Name.TrimStart($typeType.Namespace)
            }
            else {
                $typeNameShort = $typeType.Name
            }
            $typeArgs = $typeExpr.TypeName.GenericArguments # string

            $suggestedCorrections = [Collection[CorrectionExtent]]::new()

            if ($typeFullName.Length -le $MaxTypeNameLength) {
                continue
            }

            $namespace = $typeType.Namespace
            $className = $typeType.Name
            $fullName = $typeType.FullName
            $parentIsClass = $false

            if ($typeExpr.Parent -is [TypeDefinitionAst]) {
                # $typeExpr.Parent.IsClass
                # for tracking inherited class names so brackets can be left off
                $parentIsClass = $true
            }

            try {
                # Check for class name conflicts
                if ($classNameUsage.ContainsKey($className) -and
                    $classNameUsage[$className].Namespace -ne $namespace) {
                    continue # Skip if class name would conflict
                }

                $classNameUsage[$className] = @{
                    Classname = $typeNameShort
                    FullName  = $typeType.FullName
                    Namespace = $typeType.Namespace
                }

                $extent = $typeExpr.Extent
                $originalText = $extent.Text
                $classNameParams = ''
                if ($typeArgs) {
                    $classNameParams = '['
                    $typeArgsCount = 1
                    # SECTION: Using namespace param correction
                    foreach ($typeArg in $typeArgs) {
                        # original = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
                        # namespace = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
                        # name = DiagnosticRecord
                        # fullname = Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
                        Write-Verbose " ${RuleName}: Analyzing type parameter $($typeArg.Name)"
                        $typeArgOriginal = $typeArg.Name
                        $typeArgType = $typeArg.GetReflectionType()
                        $typeArgNamespace = $typeArgType.Namespace
                        $typeArgName = $typeArgType.Name
                        $typeArgFullName = $typeArgType.FullName
                        $typeArgNameShort = $typeArgFullName.TrimStart($typeArgNamespace)
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
                                $classNameUsage[$typeArgName] = @{
                                    Classname = $typeArgNameShort
                                    FullName  = $typeArgFullName
                                    Namespace = $typeArgNamespace
                                }
                                # $endLine++
                                Write-Verbose "  ${RuleName}: Added correction 'using namespace $typeArgNamespace' for type parameter $typeArgName at $endLine"
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
                    # if ($endLine -eq 1) { $endCol = 1 }
                    $endCol = $addedUsingNamespace.Length
                    $suggestedCorrections.Add([CorrectionExtent]::new(
                            $endLine,
                            $endLine,
                            1,
                            $endCol,
                            $addedUsingNamespace,
                            $extent.File,
                            "Add '$namespace' type reference"
                        ))
                    Write-Verbose "${RuleName}: Added correction 'using namespace $namespace' at $endLine"
                }

                # SECTION: Class name correction
                $BracketStart = if ($parentIsClass) { '' } else { '[' }
                $BracketEnd = if ($parentIsClass) { '' } else { ']' }
                if ($assemblyType) {
                    $correctedText = "$BracketStart$($classNameUsage[$className].Classname)$classNameParams, $AssemblyType$BracketEnd"
                }
                else {
                    $correctedText = "$BracketStart$($classNameUsage[$className].Classname)$classNameParams$BracketEnd"
                }
                # $correctedText = $originalText -replace [regex]::Escape($typeName), $className
                if ($addedUsingNamespace) {
                    $correctedLengthDifference = $correctedText.Length - $originalText.Length + $addedUsingNamespace.Length
                }
                else {
                    $correctedLengthDifference = $correctedText.Length - $originalText.Length
                }

                $CorrectionExtent = New-Object Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent

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

                #region: Calculate saved space
                <# For each type usage:
                foreach ($classEntry in $classNameUsage.GetEnumerator()) {
                    $typeNameClean = $classEntry.Value.Classname
                    $namespace = $classEntry.Value.Namespace
                    $fullTypeName = $classEntry.Value.FullName
                }
                $fullTypeLength = $typeType.FullName.Length  # e.g., "System.Collections.Generic.List"
                $shortTypeLength = $typeNameClean.Length  # e.g., "List"
                $usingStatementLength = "using namespace $namespace`n".Length  # e.g., 37 chars

                # Count all usages of this type in the file
                $typeUsageCount = $typeExpressions.Where({
                        $_.TypeName.GetReflectionType().FullName -eq $typeType.FullName
                    }).Count

                # Net savings calculation
                $savedPerUsage = $fullTypeLength - $shortTypeLength  # e.g., 32 - 4 = 28
                $totalSaved = ($savedPerUsage * $typeUsageCount) - $usingStatementLength

                # Only suggest if net positive
                if ($totalSaved -gt 0) {
                    # Add diagnostic record
                } #>
                #endregion: Calculate saved space

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
