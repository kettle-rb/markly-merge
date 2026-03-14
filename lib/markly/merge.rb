# frozen_string_literal: true

# Hard dependency - ensures markly gem is installed
require "markly"

# External gems
require "version_gem"

# Shared merge infrastructure (includes tree_haver)
require "markdown/merge"

# This gem
require_relative "merge/version"

module Markly
  # Smart merging for Markdown files using Markly AST.
  #
  # Markly::Merge provides intelligent merging of Markdown files by:
  # - Parsing Markdown into AST using Markly (cmark-gfm) via tree_haver
  # - Matching structural elements (headings, paragraphs, lists, etc.) between files
  # - Preserving frozen sections marked with HTML comments
  # - Resolving conflicts based on configurable preferences
  #
  # This is a thin wrapper around Markdown::Merge that:
  # - Provides hard dependency on the markly gem
  # - Sets markly-specific defaults (freeze token, inner_merge_code_blocks)
  # - Exposes markly-specific options (flags, extensions)
  # - Maintains API compatibility for existing users
  #
  # @example Basic merge
  #   merger = Markly::Merge::SmartMerger.new(template, destination)
  #   result = merger.merge
  #   puts result.content if result.success?
  #
  # @example With freeze blocks
  #   # In your Markdown file:
  #   # <!-- markly-merge:freeze -->
  #   # ## Custom Section
  #   # This content is preserved during merges.
  #   # <!-- markly-merge:unfreeze -->
  #
  # @see SmartMerger Main entry point for merging
  # @see Markdown::Merge::SmartMerger Underlying implementation
  module Merge

    Markdown::Merge::WrapperSupport.install!(
      wrapper_module: self,
      require_prefix: "markly/merge",
      default_freeze_token: "markly-merge",
      default_inner_merge_code_blocks: true,
      registry_tag: :markly_merge,
      merger_class: "Markly::Merge::SmartMerger",
    )
  end
end

# Ensure backend is loaded and registered
Markly::Merge.ensure_backend_loaded!


Markly::Merge::Version.class_eval do
  extend VersionGem::Basic
end
