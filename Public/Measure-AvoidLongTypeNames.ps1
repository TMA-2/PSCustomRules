#Requires -Version 5.0

using namespace System.Management.Automation
using namespace System.Management.Automation.Language
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
    [OutputType([DiagnosticRecord])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst]
        $ScriptBlockAst,

        [hashtable]$Settings = @{}
    )

    if (-not $Settings.Enable) {
        return
    }

    [int]$MaxTypeNameLength = 30

    if ($Settings.MaxLength) {
        $MaxTypeNameLength = $Settings.MaxLength
    }

    # Find all "requires" comment tokens and save the last line extent
    $ScriptBlockString = $ScriptBlockAst.ToString()
    $RequiresStatements = Find-Token -Script $ScriptBlockString -TokenKind 'Comment' | Where-Object Text -Match '^#requires -'

    [int]$endLine = 1
    foreach ($RequiresStatement in $RequiresStatements) {
        [int]$endLine = $RequiresStatement.Extent.EndLineNumber + 1
    }

    # Alternate method
    # if($ScriptBlockAst.ScriptRequirements.IsElevationRequired) {$endLine++}
    # if($ScriptBlockAst.ScriptRequirements.RequiredAssemblies) {$endLine++}
    # if($ScriptBlockAst.ScriptRequirements.RequiredModules) {$endLine++}
    # if($ScriptBlockAst.ScriptRequirements.RequiredPSEditions) {$endLine++}
    # if($ScriptBlockAst.ScriptRequirements.RequiredPSVersion) {$endLine++}

    # Check for existing using statements
    $existingUsings = $ScriptBlockAst.FindAll({
            param($ast)
            $ast -is [UsingStatementAst] -and
            $ast.UsingStatementKind -eq 'Namespace'
        }, $true)

    $defaultNamespaces = @(
        'System'
        'System.Management.Automation'
    )

    $existingNamespaces = $existingUsings | ForEach-Object { $_.Name.Value }

    # Find type expressions
    $typeExpressions = $ScriptBlockAst.FindAll({
            param($ast)
            $ast -is [TypeExpressionAst] -or
            $ast -is [TypeConstraintAst]
        }, $true)

    # Group by namespace to avoid conflicts
    $classNameUsage = @{}

    foreach ($typeExpr in $typeExpressions) {
        $typeName = $typeExpr.TypeName.FullName

        if ($typeName.Length -gt $MaxTypeNameLength -and $typeName.Contains('.') -or ($typeName -match "^$defaultNamespaces\.\w+")) {
            $lastDotIndex = $typeName.LastIndexOf('.')
            $namespace = $typeName.Substring(0, $lastDotIndex)
            $className = $typeName.Substring($lastDotIndex + 1)

            # Skip complex types and already imported namespaces
            if (-not ($className.Contains('`') -or $className.Contains('+')) -and
                $namespace -notin $existingNamespaces) {

                # Check for class name conflicts
                if ($classNameUsage.ContainsKey($className) -and
                    $classNameUsage[$className] -ne $namespace) {
                    continue # Skip if class name would conflict
                }

                $classNameUsage[$className] = $namespace

                $originalText = $typeExpr.Extent.Text
                $correctedText = $originalText -replace [regex]::Escape($typeName), $className

                $corrections = @(
                    [CorrectionExtent]::new(
                        $typeExpr.Extent.StartLineNumber,
                        $typeExpr.Extent.EndLineNumber,
                        $typeExpr.Extent.StartColumnNumber,
                        $typeExpr.Extent.EndColumnNumber,
                        $correctedText,
                        $typeExpr.Extent.File,
                        "Shorten to $className"
                    ),
                    [CorrectionExtent]::new(
                        $endLine, $endLine, 1, 1,
                        "using namespace $namespace`r`n",
                        $typeExpr.Extent.File,
                        'Add using namespace'
                    )
                )

                [DiagnosticRecord]@{
                    Message              = "Long type name detected: consider 'using namespace $namespace' and shorten to [$className]"
                    Extent               = $typeExpr.Extent
                    RuleName             = 'PSAvoidLongTypeNames'
                    Severity             = 'Information'
                    SuggestedCorrections = $corrections
                }
            }
        }
    }
}
