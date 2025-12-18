# frozen_string_literal: true

module Markly
  module Merge
    # File analysis for Markdown files using Markly.
    #
    # This is a thin wrapper around Markdown::Merge::FileAnalysis that:
    # - Forces the :markly backend
    # - Sets the default freeze token to "markly-merge"
    # - Exposes markly-specific options (flags, extensions)
    #
    # @example Basic usage
    #   analysis = FileAnalysis.new(markdown_source)
    #   analysis.statements.each do |node|
    #     puts "#{node.merge_type}: #{node.type}"
    #   end
    #
    # @example With custom freeze token
    #   analysis = FileAnalysis.new(source, freeze_token: "my-merge")
    #
    # @see Markdown::Merge::FileAnalysis Underlying implementation
    class FileAnalysis < Markdown::Merge::FileAnalysis
      # Default freeze token for markly-merge
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "markly-merge"

      # Initialize file analysis with Markly backend.
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers (default: "markly-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param flags [Integer] Markly parse flags (e.g., Markly::FOOTNOTES | Markly::SMART)
      # @param extensions [Array<Symbol>] Markly extensions to enable (e.g., [:table, :strikethrough])
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, flags: ::Markly::DEFAULT, extensions: [:table])
        super(
          source,
          backend: :markly,
          freeze_token: freeze_token,
          signature_generator: signature_generator,
          flags: flags,
          extensions: extensions,
        )
      end

      # Returns the FreezeNode class to use.
      #
      # @return [Class] Markly::Merge::FreezeNode
      def freeze_node_class
        FreezeNode
      end
    end
  end
end
