@{
    # https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme?view=ps-modules

    IncludeRules = @(
        'PSProvideCommentHelp'
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSUseCorrectCasing'
        'PSAlignAssignmentStatement'
        'PSUseConsistentIndentation'
        'PSUseConsistentWhitespace'
    )

    Rules = @{
        IncludeDefaultRules        = $true

        PSProvideCommentHelp       = @{
            Enable                  = $true
            BlockComment            = $true
            ExportedOnly            = $true
            VSCodeSnippetCorrection = $true
            Placement               = 'begin'
        }

        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }


        PSUseCorrectCasing         = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $true
            CheckOperator = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }

        PSUseConsistentWhitespace  = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $false
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
    }
}
