# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

- Updated documentation on hostile takeover of RubyGems
  - https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo

### Deprecated

### Removed

### Fixed

### Security

## [1.0.0] - 2026-02-02

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 88.14% -- 171/194 lines in 7 files
- BRANCH COVERAGE: 41.30% -- 19/46 branches in 7 files
- 78.87% documented

### Added

- Initial release of markly-merge
- Thin wrapper around `markdown-merge` for Markly backend
- `Markly::Merge::SmartMerger` - smart merging with markly defaults
  - Default freeze token: `"markly-merge"`
  - Default `inner_merge_code_blocks: true` (enabled by default)
- `Markly::Merge::FileAnalysis` - file analysis with markly backend
- `Markly::Merge::FreezeNode` - freeze block support
- Markly-specific parse options:
  - `flags:` - Markly parse flags (e.g., `Markly::FOOTNOTES`, `Markly::SMART`)
  - `extensions:` - GFM extensions (`:table`, `:strikethrough`, `:autolink`, `:tagfilter`, `:tasklist`)
- Error classes: `Error`, `ParseError`, `TemplateParseError`, `DestinationParseError`
- Re-exports shared classes from markdown-merge:
  - `FileAligner`, `ConflictResolver`, `MergeResult`
  - `TableMatchAlgorithm`, `TableMatchRefiner`, `CodeBlockMerger`
  - `NodeTypeNormalizer`
- FFI backend isolation for test suite
  - Added `bin/rspec-ffi` script to run FFI specs in isolation (before MRI backend loads)
  - Added `spec/spec_ffi_helper.rb` for FFI-specific test configuration
  - Updated Rakefile with `ffi_specs` and `remaining_specs` tasks
  - The `:test` task now runs FFI specs first, then remaining specs
- **MergeGemRegistry Integration**: Registers with `Ast::Merge::RSpec::MergeGemRegistry`
  - Enables automatic RSpec dependency tag support
  - Registers as category `:markdown`

#### Dependencies

- `ast-merge` (~> 4.0) - shared merge infrastructure
- `markly` (~> 0.15) - cmark-gfm C library
- `markdown-merge` (~> 1.0) - central merge infrastructure for markdown
- `tree_haver` (~> 5.0) - normalized AST conventions
- `version_gem` (~> 1.1) - smart versions for libraries

### Changed

- **BackendRegistry Integration**: Now uses `register_tag` instead of `register_availability_checker`
  - Registers with `require_path: "markly/merge"` enabling lazy loading
  - Tree_haver can now detect and load this backend without hardcoded knowledge
  - Supports fully dynamic tag system in tree_haver
- **SmartMerger**: Added `**options` for forward compatibility
  - Accepts additional options that may be added to base class in future
  - Passes all options through to `Markdown::Merge::SmartMerger`

### Security

[Unreleased]: https://github.com/kettle-rb/markly-merge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/markly-merge/compare/3dcd8b855b8a773f175ff34d31e3885a28a3e70b...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/markly-merge/tags/v1.0.0
