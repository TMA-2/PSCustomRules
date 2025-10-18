# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.6] - 2025-10-17

### Added
- Enhanced Find-Token cmdlet documentation with additional parameters

### Changed
- Changed `Measure-TypedVariableSpacing` extent to only highlight the type and variable
- Revised TODO.md for clarity on pending tasks and fixes
- Minor `PSSA-CustomRuleTesting.ps1` changes

### Fixed
- Refined `Measure-AvoidLongTypeNames` logic for better handling of using statements
- Improved `Measure-AvoidSimpleFunctions` to only build help info if AddHelp is specified
- Fixed `Measure-CheckParamBlockParen` extent of param statements with a newline before the paranthesis

## [0.5.5] - 2025-10-10

### Added
- `New-ScriptExtent` private function for creating custom extents for use with DiagnosticRecords

### Changed
- Adjusted `Measure-CheckParamBlockParen` extent

## [0.4.5] - 2025-10-09

### Added
- `Measure-CheckKeywordSpacing` rule scaffolded, but not complete
- Added further [TODO](TODO.md) entries for rule ideas
- Vibe-generated Pester tests for new rules

### Fixed
- `Measure-AvoidSimpleFunctions` now excludes class ctors, class methods, filters, and workspace functions
- `Measure-AvoidSimpleFunctions` no longer replaces the entire function extent -- only the first line
- `Measure-AvoidLongTypeNames` now determines the `using namespace` correction extent based on the larger of existing `#requires` and `using` entries

## [0.4.3] - 2025-10-08

### Added
- Added `Measure-AvoidSimpleFunctions` rule refactored from VSCodeProfile
- Added `findEditorSimpleFunctions` private function refactored from VSCodeProfile
- Added `Measure-CheckParamBlockParen` rule to insert space between `param` keywords and parentheses

## [0.3.3] - 2025-10-07

### Changed
- Some refactoring of rules

## [0.3.2] - 2025-10-03

### Added
- Process block to all functions
- More error handling
- Started private `Find-Type` and `Find-Constructor` functions

### Changed
- Formatted all functions

## [0.3.1] - 2025-09-25

### Changed
- ExportedFunctions in manifest to 'Measure-*'
- Moved `.vscode\PSScriptAnalyzerSettings.psd1` to root folder
- PSScriptAnalyzer settings changed to use the relative root path
- Renamed `Measure-AvoidLongTypeNames` to reflect rule name
- Renamed `Measure-UseStaticConstructor` to reflect rule name

## [0.2.1] - 2025-09-22

## Changed
- Added `Measure-NewObject` to exportedfunctions manifest field
- Changed function OutputType to `DiagnosticRecord` instead of `DiagnosticRecord[]`

## [0.1.1] - 2025-09-03

### Changed
- Moved `PSScriptAnalyzerSettings.psd1` from `\Settings` to `\.vscode`
- Added second settings file with formatting rules: `PSScriptAnalyzerSettings-Formatting.psd1`

### Fixed
- Changed script importing to dot-sourcing .ps1 and using `Import-Module` on .psm1 as the latter was just opening in Code lol.

## [0.1.0] - 2025-08-26

### Added
- Initial release.
- Added `\Private\Find-Token.ps1`
- Added rules: PSAvoidLongTypeNames, PSUseStaticConstructor, PSTypedVariableSpacing
- Added PSScriptAnalyzerSettings.psd1 referencing custom rules
