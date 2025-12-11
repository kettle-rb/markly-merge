# frozen_string_literal: true

module Markly
  module Merge
    # File analysis for Markdown files using Markly.
    #
    # Extends Markdown::Merge::FileAnalysisBase with Markly-specific parsing.
    #
    # Parses Markdown source code and extracts:
    # - Top-level block elements (headings, paragraphs, lists, code blocks, etc.)
    # - Freeze blocks marked with HTML comments
    # - Structural signatures for matching elements between files
    #
    # Freeze blocks are marked with HTML comments:
    #   <!-- markly-merge:freeze -->
    #   ... content to preserve ...
    #   <!-- markly-merge:unfreeze -->
    #
    # @example Basic usage
    #   analysis = FileAnalysis.new(markdown_source)
    #   analysis.statements.each do |node|
    #     puts "#{node.class}: #{node.type rescue 'freeze'}"
    #   end
    #
    # @example With custom freeze token
    #   analysis = FileAnalysis.new(source, freeze_token: "my-merge")
    #   # Looks for: <!-- my-merge:freeze --> / <!-- my-merge:unfreeze -->
    #
    # @see Markdown::Merge::FileAnalysisBase Base class
    class FileAnalysis < Markdown::Merge::FileAnalysisBase
      # Default freeze token for identifying freeze blocks
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "markly-merge"

      # Initialize file analysis with Markly parser
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers (default: "markly-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param flags [Integer] Markly parse flags (e.g., Markly::FOOTNOTES | Markly::SMART)
      # @param extensions [Array<Symbol>] Markly extensions to enable (e.g., [:table, :strikethrough])
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, flags: ::Markly::DEFAULT, extensions: [:table])
        @flags = flags
        @extensions = extensions
        super(source, freeze_token: freeze_token, signature_generator: signature_generator)
      end

      # Parse the source document using Markly.
      #
      # @param source [String] Markdown source to parse
      # @return [Markly::Node] Root document node
      def parse_document(source)
        ::Markly.parse(source, flags: @flags, extensions: @extensions)
      end

      # Get the next sibling of a node.
      #
      # Markly uses next (not next_sibling).
      #
      # @param node [Markly::Node] Current node
      # @return [Markly::Node, nil] Next sibling or nil
      def next_sibling(node)
        node.next
      end

      # Returns the FreezeNode class to use.
      #
      # @return [Class] Markly::Merge::FreezeNode
      def freeze_node_class
        FreezeNode
      end

      # Check if value is a Markly node.
      #
      # @param value [Object] Value to check
      # @return [Boolean] true if this is a Markly node
      def parser_node?(value)
        value.is_a?(::Markly::Node)
      end

      # Override to detect Markly nodes for signature generator fallthrough
      # @param value [Object] The value to check
      # @return [Boolean] true if this is a fallthrough node
      def fallthrough_node?(value)
        value.is_a?(::Markly::Node) || value.is_a?(FreezeNode) || super
      end

      # Compute signature for a Markly node.
      #
      # Maps Markly-specific node types to canonical signatures.
      # Note: Markly uses different type names than CommonMarker:
      # - :header instead of :heading
      # - :hrule instead of :thematic_break
      # - :blockquote instead of :block_quote
      # - :html instead of :html_block
      #
      # @param node [Markly::Node] The node
      # @return [Array, nil] Signature array
      def compute_parser_signature(node)
        type = node.type
        case type
        when :header
          # Content-based: Match headings by level and text content
          [:header, node.header_level, extract_text_content(node)]
        when :paragraph
          # Content-based: Match paragraphs by content hash (first 32 chars of digest)
          text = extract_text_content(node)
          [:paragraph, Digest::SHA256.hexdigest(text)[0, 32]]
        when :code_block
          # Content-based: Match code blocks by fence info and content hash
          content = safe_string_content(node)
          [:code_block, node.fence_info, Digest::SHA256.hexdigest(content)[0, 16]]
        when :list
          # Structure-based: Match lists by type and item count (content may differ)
          # Note: tasklist items are list_items within a list, with checked/unchecked state
          [:list, node.list_type, count_children(node)]
        when :blockquote
          # Content-based: Match block quotes by content hash
          text = extract_text_content(node)
          [:blockquote, Digest::SHA256.hexdigest(text)[0, 16]]
        when :hrule
          # Structure-based: All thematic breaks are equivalent
          [:hrule]
        when :html
          # Content-based: Match HTML blocks by content hash
          content = safe_string_content(node)
          [:html, Digest::SHA256.hexdigest(content)[0, 16]]
        when :table
          # Content-based: Match tables by structure and header content
          # Tables only match if they have the same row count AND header content
          header_content = extract_table_header_content(node)
          [:table, count_children(node), Digest::SHA256.hexdigest(header_content)[0, 16]]
        when :footnote_definition
          # Label-based: Match footnotes by their label/name
          # Footnote definitions have string_content as their label
          label = safe_string_content(node)
          [:footnote_definition, label]
        when :custom_block
          # Content-based: Match custom blocks by content hash
          text = extract_text_content(node)
          [:custom_block, Digest::SHA256.hexdigest(text)[0, 16]]
        else
          # Extension types (table_row, table_header, table_cell, strikethrough)
          # and other inline types are children of block nodes, not top-level.
          # If they somehow appear at top level, use type and position for safety.
          pos = node.source_position
          [:unknown, type, pos&.dig(:start_line)]
        end
      end

      private

      # Get node name (for footnotes, etc.)
      # @param node [Markly::Node] The node
      # @return [String, nil] Node name
      def node_name(node)
        node.respond_to?(:name) ? node.name : nil
      end
    end
  end
end
