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
            $ExportedCommands.Name | Should -Contain 'Measure-LongTypeNames'
            $ExportedCommands.Name | Should -Contain 'Measure-NewObject'
            $ExportedCommands.Name | Should -Contain 'Measure-TypedVariableSpacing'
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
            $Rule = Get-Command Measure-LongTypeNames
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
