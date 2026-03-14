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

- Documented the inherited `markdown-merge` full-document `remove_template_missing_nodes: true` contract in the wrapper README and plan, including preserved standalone HTML comment-only fragments, link reference definitions, freeze blocks, and separator-boundary stability around kept standalone fragments.
- Documented the inherited Markdown comment-ownership rollout for standalone HTML comment boundaries, matched-node fallback, partial-template link-definition preservation, and full-document fuzzy smart-merger parity through the thin wrapper.
- Added focused wrapper parity coverage for inherited removal-mode follow-ups covering destination-owned consumed link definitions that outlive removed legacy blocks, skipped fenced-code / HTML literal false positives, and preservation of only the first effective duplicate destination label.

### Changed

- Clarified that `markly-merge` keeps partial-template `replace_mode` behavior separate from the shared top-level-only removal-mode contract and continues to defer generic inline-comment promotion plus recursive/nested removal semantics.
- Clarified that broader removal-mode link-definition ownership, literal-context false-positive suppression, and duplicate-label normalization are all inherited from `markdown-merge` rather than wrapper-local logic.

### Deprecated

### Removed

### Fixed


### Security

## [1.0.0] - 2026-02-19

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 83.82% -- 171/204 lines in 7 files
- BRANCH COVERAGE: 41.30% -- 19/46 branches in 7 files
- 78.87% documented

### Added

- AGENTS.md
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
- Documentation on hostile takeover of RubyGems
  - https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo

### Security

#### Dependencies

- appraisal2 (v3.0.6)
- kettle-test (v1.0.10)
- stone_checksums (v1.0.3)
- [ast-merge (v4.0.6)](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.6) - shared merge infrastructure
- [tree_haver (v5.0.5)](https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.5) - normalized AST conventions
- [markdown-merge (v1.0.3)](https://github.com/kettle-rb/markdown-merge/releases/tag/v1.0.3) - central merge infrastructure for markdown
- tree_stump (v0.2.0)
- markly (~> 0.15) - cmark-gfm C library
- version_gem (~> 1.1) - smart versions for libraries

### Security

[Unreleased]: https://github.com/kettle-rb/markly-merge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/markly-merge/compare/3dcd8b855b8a773f175ff34d31e3885a28a3e70b...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/markly-merge/tags/v1.0.0
