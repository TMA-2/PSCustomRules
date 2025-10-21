BeforeAll {
    # Import the module under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Import PSScriptAnalyzer for testing
    Import-Module PSScriptAnalyzer -Force
}

Describe 'PSCustomRules Module Tests' {
    Context 'Module Import' {
        It 'Should import without errors' {
            { Import-Module PSCustomRules -Force } | Should -Not -Throw
        }

        It 'Should export the expected rules' {
            $ExportedCommands = Get-Command -Module PSCustomRules
            $ExportedCommands.Name | Should -Contain 'Measure-AvoidLongTypeNames'
            $ExportedCommands.Name | Should -Contain 'Measure-UseStaticConstructor'
            $ExportedCommands.Name | Should -Contain 'Measure-TypedVariableSpacing'
            $ExportedCommands.Name | Should -Contain 'Measure-AvoidSimpleFunctions'
            $ExportedCommands.Name | Should -Contain 'Measure-CheckParamBlockParen'
        }
    }
}

Describe 'PSAvoidLongTypeNames Rule Tests' {
    Context 'Rule Detection' {
        It 'Should detect long type names in variable declarations' {
            $TestScript = @'
[System.Collections.Generic.Dictionary[string, object]] $LongTypeName = @{}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidLongTypeNames'
            $Violations | Should -Not -BeNullOrEmpty
            $Violations.Count | Should -Be 1
        }

        It 'Should detect long type names in parameter declarations' {
            $TestScript = @'
function Test-Function {
    param(
        [System.Collections.Specialized.NameValueCollection] $Parameters
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidLongTypeNames'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should not flag short type names' {
            $TestScript = @'
[string] $ShortType = "test"
[int] $Number = 42
[hashtable] $Hash = @{}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidLongTypeNames'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should not flag common acceptable long types' {
            $TestScript = @'
[System.Management.Automation.PSCredential] $Credential = $null
[System.Security.SecureString] $SecureString = $null
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidLongTypeNames'
            $Violations | Should -BeNullOrEmpty
        }
    }

    Context 'Rule Metadata' {
        It 'Should have correct rule name' {
            $Rule = Get-Command Measure-AvoidLongTypeNames
            $Rule | Should -Not -BeNullOrEmpty
        }

        It 'Should return diagnostic records with correct severity' {
            $TestScript = '[System.Collections.Generic.List[System.Collections.Generic.Dictionary[string, object]]] $VeryLongType = $null'
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSAvoidLongTypeNames' | Select-Object -First 1
            $Violation.Severity | Should -BeIn @('Warning', 'Information')
        }
    }
}

Describe 'PSUseStaticConstructor Rule Tests' {
    Context 'Rule Detection' {
        It 'Should detect New-Object usage for types with static constructors' {
            $TestScript = @'
$StringBuilder = New-Object System.Text.StringBuilder
$Hashtable = New-Object System.Collections.Hashtable
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSUseStaticConstructor'
            $Violations | Should -Not -BeNullOrEmpty
            $Violations.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should not flag New-Object for COM objects' {
            $TestScript = @'
$Excel = New-Object -ComObject Excel.Application
$Word = New-Object -ComObject "Word.Application"
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSUseStaticConstructor'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should not flag static constructor usage' {
            $TestScript = @'
$StringBuilder = [System.Text.StringBuilder]::new()
$Hashtable = [hashtable]::new()
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSUseStaticConstructor'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should detect New-Object with ArgumentList parameter' {
            $TestScript = @'
$StringBuilder = New-Object System.Text.StringBuilder -ArgumentList 100
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSUseStaticConstructor'
            $Violations | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Rule Metadata' {
        It 'Should provide helpful suggestion message' {
            $TestScript = '$List = New-Object System.Collections.Generic.List[string]'
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSUseStaticConstructor' | Select-Object -First 1
            $Violation.Message | Should -Match "static constructor"
            $Violation.SuggestedCorrections | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'PSTypedVariableSpacing Rule Tests' {
    Context 'Rule Detection' {
        It 'Should detect missing space after type declaration' {
            $TestScript = @'
[string]$BadSpacing = "test"
[int]$Number = 42
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing'
            $Violations | Should -Not -BeNullOrEmpty
            $Violations.Count | Should -Be 2
        }

        It 'Should detect extra spaces after type declaration' {
            $TestScript = @'
[string]  $ExtraSpaces = "test"
[hashtable]   $MoreSpaces = @{}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should not flag correct spacing' {
            $TestScript = @'
[string] $CorrectSpacing = "test"
[int] $Number = 42
[hashtable] $Hash = @{}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should handle generic types correctly' {
            $TestScript = @'
[System.Collections.Generic.List[string]]$GenericType = [System.Collections.Generic.List[string]]::new()
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should handle parameter declarations' {
            $TestScript = @'
function Test-Function {
    param(
        [string]$BadParam,
        [int] $GoodParam
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing'
            $Violations.Count | Should -Be 1
        }
    }

    Context 'Rule Metadata' {
        It 'Should provide correction suggestions' {
            $TestScript = '[string]$BadSpacing = "test"'
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing' | Select-Object -First 1
            $Violation.SuggestedCorrections | Should -Not -BeNullOrEmpty
            $Violation.SuggestedCorrections[0].Description | Should -Match "single space"
        }

        It 'Should have appropriate severity level' {
            $TestScript = '[int]$Number = 42'
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSTypedVariableSpacing' | Select-Object -First 1
            $Violation.Severity | Should -BeIn @('Warning', 'Information')
        }
    }
}

Describe 'PSAvoidSimpleFunctions Rule Tests' {
    Context 'Should detect simple functions' {
        It 'Should detect simple function with inline parameters' {
            $TestScript = @'
function SimpleFunction([string]$Msg) {
    Write-Output $Msg
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should detect simple function with multiple inline parameters' {
            $TestScript = @'
function SimpleFunctionWithAttr([Parameter(Mandatory,Position=0)][string]$Msg, [switch]$Flag, [ValidateRange(1,10)][int]$Count=1) {
    if ($Flag) {
        Write-Output "Count: ${Count}, Message: $Msg"
    }
    else {
        Write-Output $Msg
    }
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should detect nested simple functions inside advanced functions' {
            $TestScript = @'
function AdvFunction {
    [CmdletBinding()]
    param(
        [string] $Msg
    )

    begin {
        function local:logMsg([string]$Msg) {
            Write-Host $Msg
        }
    }

    process {
        local:logMsg $Msg
    }
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            # Should detect the nested simple function
            $Violations | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Should not trigger on advanced functions' {
        It 'Should not flag filter functions' {
            $TestScript = @'
filter SimpleFilter {
    Write-Output $_
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should not flag functions with param blocks' {
            $TestScript = @'
function AdvFunction {
    [CmdletBinding()]
    param(
        [string] $Msg
    )

    process {
        Write-Output $Msg
    }
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            # Should only detect issues on the advanced function itself, not the param block
            # (Advanced functions are allowed to have param blocks)
            $AdvFunctionViolations = $Violations | Where-Object { $_.Extent.Text -match 'function AdvFunction' }
            $AdvFunctionViolations | Should -BeNullOrEmpty
        }

        It 'Should not flag class methods' {
            $TestScript = @'
class DemoClass {
    [string]$Message

    DemoClass() {
        $this.SetMessage("Default Message")
    }

    DemoClass([string]$Msg) {
        $this.SetMessage($Msg)
    }

    [void] SetMessage([string]$Msg) {
        $this.Message = $Msg
    }

    [void] WriteMessage() {
        [console]::WriteLine($this.Message)
    }
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions'
            # Class methods should not trigger this rule
            $Violations | Should -BeNullOrEmpty
        }
    }

    Context 'SuggestedCorrections' {
        It 'Should provide correction to add param block' {
            $TestScript = @'
function SimpleFunction([string]$Msg) {
    Write-Output $Msg
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSAvoidSimpleFunctions' | Select-Object -First 1
            $Violation.SuggestedCorrections | Should -Not -BeNullOrEmpty
            $Violation.SuggestedCorrections[0].Description | Should -Match 'param'
        }
    }
}

Describe 'PSCheckParamBlockParen Rule Tests' {
    Context 'Should detect spacing issues' {
        It 'Should detect missing space after param keyword' {
            $TestScript = @'
function Test-Function {
    param(
        [string]$Parameter
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSCheckParamBlockParen'
            $Violations | Should -Not -BeNullOrEmpty
        }

        It 'Should detect extra spaces after param keyword' {
            $TestScript = @'
function Test-Function {
    param  (
        [string]$Parameter
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSCheckParamBlockParen'
            $Violations | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Should not trigger on correct spacing' {
        It 'Should not flag correct param block spacing' {
            $TestScript = @'
function Test-Function {
    param (
        [string]$Parameter
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSCheckParamBlockParen'
            $Violations | Should -BeNullOrEmpty
        }

        It 'Should handle multiple parameters correctly' {
            $TestScript = @'
function Test-Function {
    param (
        [string]$Param1,

        [int]$Param2,

        [switch]$Param3
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violations = $Results | Where-Object RuleName -EQ 'PSCheckParamBlockParen'
            $Violations | Should -BeNullOrEmpty
        }
    }

    Context 'SuggestedCorrections' {
        It 'Should provide correction for spacing' {
            $TestScript = @'
function Test-Function {
    param(
        [string]$Parameter
    )
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $Violation = $Results | Where-Object RuleName -EQ 'PSCheckParamBlockParen' | Select-Object -First 1
            if ($Violation) {
                $Violation.SuggestedCorrections | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Integration Tests' {
    Context 'Multiple Rules' {
        It 'Should detect multiple rule violations in the same script' {
            $TestScript = @'
[System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]$LongTypeNoSpace = New-Object System.Collections.Generic.Dictionary[string, object]
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            $RuleNames = $Results.RuleName | Sort-Object -Unique
            $RuleNames | Should -Contain 'PSAvoidLongTypeNames'
            $RuleNames | Should -Contain 'PSUseStaticConstructor'
            $RuleNames | Should -Contain 'PSTypedVariableSpacing'
        }

        It 'Should work with standard PSScriptAnalyzer rules' {
            $TestScript = @'
function test-function {
    [string]$var = New-Object System.Text.StringBuilder
}
'@
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $TestScript -CustomRulePath $ModulePath
            # Should detect both custom rules and standard rules (like function naming)
            $Results | Should -Not -BeNullOrEmpty
        }
    }
}
