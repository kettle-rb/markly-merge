# Blank Line Normalization Plan for `markly-merge`

_Date: 2026-03-19_

## Role in the family refactor

`markly-merge` is a thin Markdown-family wrapper repo for this effort.

Its job is parity with `markdown-merge`, not inventing a separate blank-line contract.

## Source of truth

For concrete behavior, implementation direction, and most new semantics, follow:

- `../markdown-merge/BLANK_LINE_NORMALIZATION_PLAN.md`
- `markdown-merge/README.md`
- shared wrapper-facing specs and entry points

## Current evidence files

- `lib/markly/merge/smart_merger.rb`
- `spec/markly/merge/smart_merger_spec.rb`
- `README.md`

## Migration targets

- keep wrapper entry points aligned with `markdown-merge`
- preserve wrapper-level parity for blank-line-sensitive regressions
- avoid wrapper-local blank-line heuristics unless a wrapper-specific backend issue truly requires them

## Workstreams

- mirror shared behavior added in `markdown-merge`
- add/update parity specs when Markdown-family blank-line cases expand
- keep repo-local implementation thinner, not thicker, as the shared layout model lands

## Exit criteria

- wrapper behavior matches `markdown-merge` for the supported blank-line cases
- no unnecessary wrapper-local newline handling is introduced
