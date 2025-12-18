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
    # Base error class for Markly::Merge
    # Inherits from Markdown::Merge::Error for consistency across merge gems.
    class Error < Markdown::Merge::Error; end

    # Raised when a Markdown file has parsing errors.
    # Inherits from Markdown::Merge::ParseError for consistency across merge gems.
    class ParseError < Markdown::Merge::ParseError; end

    # Raised when the template file has syntax errors.
    class TemplateParseError < ParseError; end

    # Raised when the destination file has syntax errors.
    class DestinationParseError < ParseError; end

    # Default freeze token for markly-merge
    # @return [String]
    DEFAULT_FREEZE_TOKEN = "markly-merge"

    # Default inner_merge_code_blocks setting for markly-merge
    # @return [Boolean]
    DEFAULT_INNER_MERGE_CODE_BLOCKS = true

    # Re-export shared classes from markdown-merge
    FileAligner = Markdown::Merge::FileAligner
    ConflictResolver = Markdown::Merge::ConflictResolver
    MergeResult = Markdown::Merge::MergeResult
    TableMatchAlgorithm = Markdown::Merge::TableMatchAlgorithm
    TableMatchRefiner = Markdown::Merge::TableMatchRefiner
    CodeBlockMerger = Markdown::Merge::CodeBlockMerger
    NodeTypeNormalizer = Markdown::Merge::NodeTypeNormalizer

    autoload :DebugLogger, "markly/merge/debug_logger"
    autoload :FreezeNode, "markly/merge/freeze_node"
    autoload :FileAnalysis, "markly/merge/file_analysis"
    autoload :SmartMerger, "markly/merge/smart_merger"
  end
end

Markly::Merge::Version.class_eval do
  extend VersionGem::Basic
end
