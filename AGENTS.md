# AGENTS.md - markly-merge Development Guide

## 🎯 Project Overview

`markly-merge` is a **format-specific implementation of the `*-merge` gem family** for Markdown files using the Markly parser. It provides intelligent Markdown file merging using AST analysis.

**Core Philosophy**: Intelligent Markdown merging that preserves structure, formatting, and links while applying updates from templates.

**Repository**: https://github.com/kettle-rb/markly-merge
**Current Version**: 1.0.0
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## 🏗️ Architecture: Format-Specific Implementation

### What markly-merge Provides

- **`Markly::Merge::SmartMerger`** – Markdown-specific SmartMerger implementation
- **`Markly::Merge::FileAnalysis`** – Markdown file analysis with section extraction
- **`Markly::Merge::NodeWrapper`** – Wrapper for Markly AST nodes
- **`Markly::Merge::PartialTemplateMerger`** – Section-level partial merges
- **`Markly::Merge::MergeResult`** – Markdown-specific merge result
- **`Markly::Merge::ConflictResolver`** – Markdown conflict resolution
- **`Markly::Merge::FreezeNode`** – Markdown freeze block support
- **`Markly::Merge::DebugLogger`** – Markly-specific debug logging

### Key Dependencies

| Gem | Role |
|-----|------|
| `ast-merge` (~> 4.0) | Base classes and shared infrastructure |
| `tree_haver` (~> 5.0) | Unified parser adapter (wraps Markly) |
| `markly` (~> 0.15) | CommonMark Markdown parser (MRI only) |
| `version_gem` (~> 1.1) | Version management |

### Parser Backend

markly-merge uses the Markly parser exclusively via TreeHaver's `:markly` backend:

| Backend | Parser | Platform | Notes |
|---------|--------|----------|-------|
| `:markly` | Markly | MRI only | Fast CommonMark parser, native extension |

## 📁 Project Structure

```
lib/markly/merge/
├── smart_merger.rb              # Main SmartMerger implementation
├── partial_template_merger.rb   # Section-level merging
├── file_analysis.rb             # Markdown file analysis
├── node_wrapper.rb              # AST node wrapper
├── merge_result.rb              # Merge result object
├── conflict_resolver.rb         # Conflict resolution
├── freeze_node.rb               # Freeze block support
├── debug_logger.rb              # Debug logging
└── version.rb

spec/markly/merge/
├── smart_merger_spec.rb
├── partial_template_merger_spec.rb
├── file_analysis_spec.rb
└── integration/
```

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
bundle exec rspec

# Single file (disable coverage threshold check)
K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/markly/merge/smart_merger_spec.rb

# Markly backend tests
bundle exec rspec --tag markly
```

### Coverage Reports

```bash
cd /home/pboling/src/kettle-rb/ast-merge/vendor/markly-merge
bin/rake coverage && bin/kettle-soup-cover -d
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API
- `merge` – Returns a **String** (the merged Markdown content)
- `merge_result` – Returns a **MergeResult** object
- `to_s` on MergeResult returns the merged content as a string

#### PartialTemplateMerger API
- `merge` – Merges a template section into a specific location in destination
- Used by `ast-merge-recipe` for section-level updates

#### Markdown-Specific Features

**Heading-Based Sections**:
```markdown
# Section 1
Content for section 1

## Subsection 1.1
Nested content

# Section 2
Content for section 2
```

**Freeze Blocks**:
```markdown
<!-- markly-merge:freeze -->
Custom content that should not be overridden
<!-- markly-merge:unfreeze -->

Standard content that merges normally
```

**Link Reference Preservation**:
```markdown
[link text][ref]

[ref]: https://example.com
```

## 🧪 Testing Patterns

### TreeHaver Dependency Tags

**Available tags**:
- `:markly` – Requires Markly backend
- `:markdown_parsing` – Requires Markdown parser

✅ **CORRECT**:
```ruby
RSpec.describe Markly::Merge::SmartMerger, :markly do
  # Skipped if Markly not available
end
```

❌ **WRONG**:
```ruby
before do
  skip "Requires Markly" unless defined?(Markly)  # DO NOT DO THIS
end
```

## 💡 Key Insights

1. **Heading-based structure**: Sections matched by heading text
2. **`.text` strips formatting**: When matching by text, backticks and other formatting are removed
3. **Link references preserved**: Reference-style links maintained during merge
4. **PartialTemplateMerger**: Supports injecting template sections into specific locations
5. **Freeze blocks use HTML comments**: `<!-- markly-merge:freeze -->`
6. **MRI only**: Markly requires native extensions, MRI only

## 🚫 Common Pitfalls

1. **Markly requires MRI**: Does not work on JRuby or TruffleRuby
2. **NEVER use manual skip checks** – Use dependency tags (`:markly`)
3. **Text matching strips formatting** – Match on plain text, not markdown syntax
4. **Do NOT load vendor gems** – They are not part of this project; they do not exist in CI
5. **Use `tmp/` for temporary files** – Never use `/tmp` or other system directories

## 🔧 Markdown-Specific Notes

### Node Types
```markdown
document         # Root node
heading          # # Heading
paragraph        # Regular text
code_block       # ```code```
list             # - item or 1. item
link             # [text](url)
image            # ![alt](src)
```

### Text Matching Behavior
```markdown
Source:     ### The `*-merge` Gem Family
.text:      "The *-merge Gem Family\n"

# Backticks, bold, italic stripped in .text
```

### Merge Behavior
- **Headings**: Matched by heading text (stripped of formatting)
- **Sections**: Content from heading to next same-level heading
- **Paragraphs**: Position-based within sections
- **Code blocks**: Matched by language and content
- **Lists**: Can be merged or replaced
- **Links**: Reference-style links preserved
- **Freeze blocks**: Protect customizations from template updates
