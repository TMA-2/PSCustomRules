# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
