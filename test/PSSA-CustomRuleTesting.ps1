#requires -Version 5.1

#region PSAvoidLongTypeNames testing
using namespace System.Collections.Specialized
using namespace System.Management.Automation
using module PSCustomRules
using assembly 'c:\Program Files\PowerShell\7\Microsoft.PowerShell.Commands.Utility.dll'
# this comment should not get overwritten by the rule!

# SKIP: type names that are part of the rule exceptions
# < 30 chars
$ArrayList = [System.Collections.ArrayList]::new()
# < 30 chars, aliasing longer type name
$OrderedDictionaryAlias = [OrderedDictionary]::new()
# > 30 chars, already referenced
$OrderedDictionaryFull = [System.Collections.Specialized.OrderedDictionary]::new()

# CORRECT: Type names that should be included
# > 30 chars
$ByteEqualityComparer = [ByteEqualityComparer]::new()
# > 30 chars, < 40 chars
$GenericList = [System.Collections.Generic.KeyValuePair]::Create()
# Parameterized type (short)
$OrderedDictionaryString = [System.Collections.Generic.OrderedDictionary[string, string]]::new()
# Parameterized type (long)
$DiagnosticList = [System.Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]::new()
# Double-parameterized type name
$DoubleParamType = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new()
# Assembly-qualified type name
$AssemblyQualifiedType = [Microsoft.PowerShell.PSConsoleReadLineOptions, Microsoft.PowerShell]::new()
#endregion PSAvoidLongTypeNames testing

#region PSUseStaticConstructor testing
# Skip -COMObject
$FSOObject = New-Object -ComObject "Scripting.FileSystemObject"
# Plain constructor
$StringBuilder = New-Object System.Text.StringBuilder
# Constructor with one argument
$StringBuilderArg = New-Object System.Text.StringBuilder -ArgumentList "Initial String"
# Constructor with multiple typed arguments
$StringBuilderArgs = New-Object System.Text.StringBuilder -ArgumentList @([string]"Initial String", [int]256)
# Constructor with -Property hashtable
$PSObject = New-Object System.Management.Automation.PSCustomObject -Property @{ Key1 = "Test"; Key2 = 123 }
#endregion PSUseStaticConstructor testing

#region PSAlignEnumStatement testing
Enum TestEnum {
    Unknown = -1 # Test block comment handling
    Boot <# Test stream comment handling #> = 0
    System = 1
    Auto = 2
    Automatic = 2
    Manual = 3
    Disabled = 4
}

[FlagsAttribute()]
Enum TestEnumBitwise {
    ValueZero = 0x00
    ValueOne # = 0x01
    ValueTwo # = 0x02
    ValueEight = 0x08
    ValueSixteen = 0x10
}
#endregion PSAlignEnumStatement testing

#region PSAvoidSimpleFunctions testing
# SECTION: simple function
function SimpleFunction([string] $Msg) {
    Write-Output $Msg
}
# SECTION: Filter function
filter SimpleFilter {
    Write-Output $_
}
# SECTION Workflow function
# workflow WorkflowFunction {
#     Write-Output "In Workflow"
# }
# SECTION DSC function
configuration DSCFunction {
    Node localhost {
        Write-Output "In DSC"
    }
}
# SECTION: simple function with inline attributes
function private:SimpleFunctionWithAttr([Parameter(Mandatory,Position=0)][string]$Msg, [switch]$Flag, [ValidateRange(1,10)][int]$Count=1) {
    if ($Flag) {
        Write-Output "Count: $Count, Message: $Msg"
    }
    else {
        Write-Output $Msg
    }
}

# SECTION: simple function with multi-line parameters
function SimpleFunctionWithAttr(
    [string]$Msg,
    [switch]$Flag,
    [int]$Count=1
    )
    {
    # a comment, wow
    if ($Flag) {
        Write-Output "Count: $Count, Message: $Msg"
    } else {
        Write-Output $Msg
    }
}

# SECTION: param block within function
function AdvFunction {
    [CmdletBinding()]
    param(
        [string] $Msg
    )

    # simple function inside advanced function
    begin {
        function local:logMsg([string]$Msg) {
            Write-Host $Msg
        }
    }

    process {
        local:logMsg $Msg
    }

    end {
        local:logMsg "End of AdvFunction"
    }
}

# NOTE: THIS SHOULD ALL BE AVOIDED
class DemoClass {
    [string]$Message

    # default ctor
    DemoClass() {
        $this.SetMessage("Default Message")
    }

    # parameterized ctor
    DemoClass([string]$Msg) {
        $this.SetMessage($Msg)
    }

    # method w/ param
    [void] SetMessage([string]$Msg) {
        $this.Message = $Msg
    }

    # method w/o param
    [void] WriteMessage() {
        [console]::WriteLine($this.Message)
    }
}
#endregion PSAvoidSimpleFunctions testing

#region PSCheckParamBlockParen testing
# FIX: param block without space
function Test-ParamNoSpace {
    param(
        [string]$Param1 = 'defaultvalue'
    )
    Write-Output $Param1
}

# FIX: param block with newline instead of space (weird edge case)
function Test-ParamNewLine {
    param
    (
        [string]$Param1
    )
    Write-Output $Param1
}

# SKIP: param block with proper spacing
function Test-ParamSpace {
    param (
        [string]$Param1
    )
    Write-Output $Param1
}
#endregion PSCheckParamBlockParen testing

#region Keyword and Unary Operators
# if, elseif
if($true) {
    <# Action to perform if the condition is true #>
}
elseif($false) {
    <# Action to perform if the condition is false #>
}
# for
for($i = 0; $i -lt $Error.Count; $i++) {
    <# Action that will repeat until the condition is met #>
}
# foreach
foreach($Item in $Col) {
    <# $Item is the current item #>
}
# while
while($true) {
    <# Loop action #>
}
# do while
do {
    <# Loop action #>
}while($true)
# do until
do {
    <# Loop action #>
}until($true)
# switch
switch($x) {
    1 {
        <# Action to perform #>
    }
    default {
        return
    }
}
#endregion Keyword and Unary Operators
