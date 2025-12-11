# frozen_string_literal: true

module Markly
  module Merge
    # Orchestrates the smart merge process for Markdown files using Markly.
    #
    # Extends Markdown::Merge::SmartMergerBase with Markly-specific parsing.
    #
    # Uses FileAnalysis, FileAligner, ConflictResolver, and MergeResult to
    # merge two Markdown files intelligently. Freeze blocks marked with
    # HTML comments are preserved exactly as-is.
    #
    # SmartMerger provides flexible configuration for different merge scenarios:
    # - Preserve destination customizations (default)
    # - Apply template updates
    # - Add new sections from template
    # - Inner-merge fenced code blocks using language-specific mergers (default: enabled)
    #
    # @example Basic merge (destination customizations preserved)
    #   merger = SmartMerger.new(template_content, dest_content)
    #   result = merger.merge
    #   if result.success?
    #     File.write("output.md", result.content)
    #   end
    #
    # @example Template updates win
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     preference: :template,
    #     add_template_only_nodes: true
    #   )
    #   result = merger.merge
    #
    # @example Custom signature matching
    #   sig_gen = ->(node) {
    #     if node.respond_to?(:type) && node.type == :header
    #       [:header, node.header_level]  # Match by level only, not content
    #     else
    #       node  # Fall through to default
    #     end
    #   }
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     signature_generator: sig_gen
    #   )
    #
    # @example Disable inner-merge for code blocks
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     inner_merge_code_blocks: false
    #   )
    #
    # @see FileAnalysis
    # @see Markdown::Merge::SmartMergerBase
    class SmartMerger < Markdown::Merge::SmartMergerBase
      # Creates a new SmartMerger for intelligent Markdown file merging.
      #
      # @param template_content [String] Template Markdown source code
      # @param dest_content [String] Destination Markdown source code
      #
      # @param signature_generator [Proc, nil] Optional proc to generate custom node signatures.
      #   The proc receives a Markly::Node and should return one of:
      #   - An array representing the node's signature
      #   - `nil` to indicate the node should have no signature
      #   - The original node to fall through to default signature computation
      #
      # @param preference [Symbol] Controls which version to use when nodes
      #   have matching signatures but different content:
      #   - `:destination` (default) - Use destination version (preserves customizations)
      #   - `:template` - Use template version (applies updates)
      #
      # @param add_template_only_nodes [Boolean] Controls whether to add nodes that only
      #   exist in template:
      #   - `false` (default) - Skip template-only nodes
      #   - `true` - Add template-only nodes to result
      #
      # @param inner_merge_code_blocks [Boolean, CodeBlockMerger] Controls inner-merge for
      #   fenced code blocks:
      #   - `true` (default) - Enable inner-merge using default CodeBlockMerger
      #   - `false` - Disable inner-merge (use standard conflict resolution)
      #   - `CodeBlockMerger` instance - Use custom CodeBlockMerger
      #
      # @param freeze_token [String] Token to use for freeze block markers.
      #   Default: "markly-merge"
      #   Looks for: <!-- markly-merge:freeze --> / <!-- markly-merge:unfreeze -->
      #
      # @param flags [Integer] Markly parse flags (e.g., Markly::FOOTNOTES | Markly::SMART).
      #   Default: Markly::DEFAULT
      #   Available flags:
      #   - Markly::FOOTNOTES - Parse footnotes
      #   - Markly::SMART - Use smart punctuation (curly quotes, etc.)
      #   - Markly::VALIDATE_UTF8 - Replace illegal sequences with replacement character
      #   - Markly::LIBERAL_HTML_TAG - Support liberal parsing of inline HTML tags
      #   - Markly::STRIKETHROUGH_DOUBLE_TILDE - Require double tildes for strikethrough
      #   - Markly::UNSAFE - Allow raw/custom HTML and unsafe links
      #
      # @param extensions [Array<Symbol>] Markly extensions to enable (e.g., [:table, :strikethrough])
      #   Available extensions: :table, :strikethrough, :autolink, :tagfilter, :tasklist
      #
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching of
      #   unmatched nodes. Default: nil (fuzzy matching disabled).
      #   Set to TableMatchRefiner.new to enable fuzzy table matching.
      #
      # @raise [TemplateParseError] If template has syntax errors
      # @raise [DestinationParseError] If destination has syntax errors
      def initialize(
        template_content,
        dest_content,
        signature_generator: nil,
        preference: :destination,
        add_template_only_nodes: false,
        inner_merge_code_blocks: true,
        freeze_token: FileAnalysis::DEFAULT_FREEZE_TOKEN,
        flags: ::Markly::DEFAULT,
        extensions: [:table],
        match_refiner: nil
      )
        @flags = flags
        @extensions = extensions
        super(
          template_content,
          dest_content,
          signature_generator: signature_generator,
          preference: preference,
          add_template_only_nodes: add_template_only_nodes,
          inner_merge_code_blocks: inner_merge_code_blocks,
          freeze_token: freeze_token,
          match_refiner: match_refiner,
          flags: flags,
          extensions: extensions,
        )
      end

      # Create a FileAnalysis instance for Markly parsing.
      #
      # @param content [String] Markdown content to analyze
      # @param options [Hash] Analysis options
      # @return [FileAnalysis] Markly-specific file analysis
      def create_file_analysis(content, **opts)
        FileAnalysis.new(
          content,
          freeze_token: opts[:freeze_token],
          signature_generator: opts[:signature_generator],
          flags: opts[:flags] || @flags,
          extensions: opts[:extensions] || @extensions,
        )
      end

      # Returns the TemplateParseError class to use.
      #
      # @return [Class] Markly::Merge::TemplateParseError
      def template_parse_error_class
        TemplateParseError
      end

      # Returns the DestinationParseError class to use.
      #
      # @return [Class] Markly::Merge::DestinationParseError
      def destination_parse_error_class
        DestinationParseError
      end

      # Convert a node to its source text.
      #
      # @param node [Object] Node to convert
      # @param analysis [FileAnalysis] Analysis for source lookup
      # @return [String] Source text
      def node_to_source(node, analysis)
        # Check for any FreezeNode type (base class or subclass)
        if node.is_a?(Ast::Merge::FreezeNodeBase)
          node.full_text
        else
          pos = node.source_position
          start_line = pos&.dig(:start_line)
          end_line = pos&.dig(:end_line)

          return node.to_commonmark unless start_line && end_line

          analysis.source_range(start_line, end_line)
        end
      end
    end
  end
end
