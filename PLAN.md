# PLAN.md

## Goal
Adopt the shared Comment AST & Merge capability in `markly-merge` by inheriting the Markdown-core implementation from `markdown-merge` and keeping this gem a thin backend wrapper.

`psych-merge` is the shared comment API reference, but `markdown-merge` is the direct implementation dependency for this wrapper plan.

## Current Status
- `markly-merge` should stay thin and backend-focused rather than reimplementing Markdown comment behavior locally.
- The gem has the standard merge-gem layout and should mostly capture Markly-specific defaults and integration coverage.
- Any substantial comment-region logic should be built in `markdown-merge` first.
- This plan should remain small and parity-focused.

## Integration Strategy
- Wait for the Markdown-core comment capability to settle in `markdown-merge`.
- Surface the shared capability through wrapper file analysis / merger entry points.
- Add only Markly-specific normalization needed for ranges, defaults, or parser quirks.
- Keep wrapper-specific work focused on integration coverage and explicit defaults.

## First Slices
1. Do not duplicate Markdown-core work in this wrapper.
2. Once core support exists, expose the shared comment capability through the wrapper API.
3. Add wrapper integration specs that prove standalone comment regions survive Markly-backed merges.
4. Fix only backend-specific range/default issues that block parity with `markdown-merge`.

## First Files To Inspect
- `lib/markly/merge/file_analysis.rb`
- `lib/markly/merge/smart_merger.rb`
- any backend wiring under `lib/markly/merge/`
- wrapper-focused specs under `spec/markly/merge/`

## Tests To Add First
- backend integration specs after `markdown-merge` support lands
- wrapper smart merger specs for standalone comment regions
- shared parity fixtures with `markdown-merge`
- targeted regressions only for Markly-specific position/default issues

## Risks
- Duplicating core behavior here would create wrapper drift.
- Markly-specific range quirks may require thin normalization.
- Wrapper defaults must remain explicit and small.
- The wrapper should not become a second Markdown-core implementation.

## Success Criteria
- This wrapper remains thin and backend-specific.
- Shared comment capability flows through from `markdown-merge` with minimal extra code.
- Markly-specific quirks are covered by small targeted tests.
- Wrapper integration specs prove parity with the shared Markdown behavior.

## Rollout Phase
- Phase 3 target.
- Start only after the Markdown-core plan is stable enough to inherit.

## Execution Backlog

### Slice 1 — Wrapper passthrough
- Expose the shared comment capability through the wrapper once `markdown-merge` provides it.
- Add thin integration specs proving standalone comment regions survive Markly-backed merges.
- Keep wrapper behavior limited to defaults and backend wiring.

### Slice 2 — Backend-specific normalization only
- Fix only Markly-specific range/default issues that block parity with the Markdown core.
- Reuse shared Markdown fixtures and avoid local comment algorithms.
- Keep wrapper-level changes narrow and easy to reason about.

### Slice 3 — Wrapper-specific defaults polish
- Re-check wrapper defaults, code-block merge defaults, and partial-merge integration under the new comment capability.
- Add only small targeted regressions where Markly behavior differs materially.

## Dependencies / Resume Notes
- Do not start here until `vendor/markdown-merge/PLAN.md` Slice 2 is stable.
- Inspect `lib/markly/merge/file_analysis.rb` and wrapper integration specs first.
- Favor parity with `markdown-merge` over bespoke wrapper behavior.

## Exit Gate For This Plan
- The wrapper remains thin while proving Markly-backed parity with the Markdown core comment behavior.
