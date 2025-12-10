# frozen_string_literal: true

# External gems
require "markly"
require "version_gem"
require "set"

# Shared merge infrastructure
require "ast/merge"

# This gem
require_relative "merge/version"

module Markly
  # Smart merging for Markdown files using Markly AST.
  #
  # Markly::Merge provides intelligent merging of Markdown files by:
  # - Parsing Markdown into AST using Markly
  # - Matching structural elements (headings, paragraphs, lists, etc.) between files
  # - Preserving frozen sections marked with HTML comments
  # - Resolving conflicts based on configurable preferences
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
  # @see FileAnalysis For parsing and analyzing Markdown files
  # @see FreezeNode For understanding freeze block behavior
  module Merge
    # Base error class for Markly::Merge
    # Inherits from Ast::Merge::Error for consistency across merge gems.
    class Error < Ast::Merge::Error; end

    # Raised when a Markdown file has parsing errors.
    # Inherits from Ast::Merge::ParseError for consistency across merge gems.
    #
    # @example Handling parse errors
    #   begin
    #     analysis = FileAnalysis.new(markdown_content)
    #   rescue ParseError => e
    #     puts "Markdown syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error}" }
    #   end
    class ParseError < Ast::Merge::ParseError
      # @param message [String, nil] Error message (auto-generated if nil)
      # @param content [String, nil] The Markdown source that failed to parse
      # @param errors [Array] Parse errors from Markly
      def initialize(message = nil, content: nil, errors: [])
        super(message, errors: errors, content: content)
      end
    end

    # Raised when the template file has syntax errors.
    #
    # @example Handling template parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue TemplateParseError => e
    #     puts "Template syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error.message}" }
    #   end
    class TemplateParseError < ParseError; end

    # Raised when the destination file has syntax errors.
    #
    # @example Handling destination parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue DestinationParseError => e
    #     puts "Destination syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error.message}" }
    #   end
    class DestinationParseError < ParseError; end

    autoload :CodeBlockMerger, "markly/merge/code_block_merger"
    autoload :DebugLogger, "markly/merge/debug_logger"
    autoload :FreezeNode, "markly/merge/freeze_node"
    autoload :MergeResult, "markly/merge/merge_result"
    autoload :FileAnalysis, "markly/merge/file_analysis"
    autoload :FileAligner, "markly/merge/file_aligner"
    autoload :ConflictResolver, "markly/merge/conflict_resolver"
    autoload :SmartMerger, "markly/merge/smart_merger"
    autoload :TableMatchAlgorithm, "markly/merge/table_match_algorithm"
    autoload :TableMatchRefiner, "markly/merge/table_match_refiner"
  end
end

Markly::Merge::Version.class_eval do
  extend VersionGem::Basic
end
