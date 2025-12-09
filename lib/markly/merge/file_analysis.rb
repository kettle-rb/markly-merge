# frozen_string_literal: true

require "digest"

module Markly
  module Merge
    # File analysis for Markdown files using Markly.
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
    class FileAnalysis
      include Ast::Merge::FileAnalyzable

      # Default freeze token for identifying freeze blocks
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "markly-merge"

      # @return [Markly::Node] The root document node
      attr_reader :document

      # Initialize file analysis with Markly parser
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers (default: "markly-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param flags [Integer] Markly parse flags (e.g., Markly::FOOTNOTES | Markly::SMART)
      # @param extensions [Array<Symbol>] Markly extensions to enable (e.g., [:table, :strikethrough])
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, flags: Markly::DEFAULT, extensions: [:table])
        @source = source
        @lines = source.split("\n", -1)
        @freeze_token = freeze_token
        @signature_generator = signature_generator
        @flags = flags
        @extensions = extensions

        # Parse the Markdown source
        @document = DebugLogger.time("FileAnalysis#parse") do
          Markly.parse(source, flags: @flags, extensions: @extensions)
        end

        # Extract and integrate all nodes including freeze blocks
        @statements = extract_and_integrate_all_nodes

        DebugLogger.debug("FileAnalysis initialized", {
          signature_generator: signature_generator ? "custom" : "default",
          document_children: count_children(@document),
          statements_count: @statements.size,
          freeze_blocks: freeze_blocks.size,
        })
      end

      # Check if parse was successful
      # @return [Boolean]
      def valid?
        !@document.nil?
      end

      # Get all statements (block nodes outside freeze blocks + FreezeNodeBase subclasses)
      # @return [Array<Markly::Node, FreezeNodeBase>]
      attr_reader :statements

      # Compute default signature for a node
      # @param node [Object] The Markly::Node or FreezeNodeBase subclass
      # @return [Array, nil] Signature array
      def compute_node_signature(node)
        case node
        when FreezeNode
          node.signature
        else
          compute_markly_signature(node)
        end
      end

      # Compute signature for a Markly node.
      #
      # Signatures determine which nodes match between template and destination.
      # Some signatures are content-based (paragraphs, code blocks, block quotes, html blocks)
      # meaning nodes only match if content is identical.
      #
      # Other signatures are structure-based (lists, tables, thematic breaks) meaning
      # nodes can match even with different content - this allows the merge preference
      # to determine which version to use.
      #
      # ## Supported Node Types
      #
      # ### Block nodes (top-level):
      # - `:header` - Content-based: matches by level and text content
      # - `:paragraph` - Content-based: matches by content hash
      # - `:code_block` - Content-based: matches by fence info and content hash
      # - `:list` - Structure-based: matches by type and item count
      # - `:blockquote` - Content-based: matches by content hash
      # - `:hrule` - Structure-based: all thematic breaks are equivalent
      # - `:html` - Content-based: matches by content hash
      # - `:table` - Content-based: matches by structure and header content
      # - `:footnote_definition` - Name-based: matches by footnote label
      # - `:custom_block` - Content-based: matches by content hash
      #
      # ### Extension nodes:
      # - `:strikethrough` - Inline, handled as part of parent content
      # - `:table_row`, `:table_header`, `:table_cell` - Children of table, not top-level
      # - tasklist items use `:list_item` type with special attributes
      #
      # @param node [Markly::Node] The node
      # @return [Array, nil] Signature array
      def compute_markly_signature(node)
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

      # Safely get string content from a node
      # @param node [Markly::Node] The node
      # @return [String] String content or empty string
      def safe_string_content(node)
        node.string_content.to_s
      rescue TypeError
        # Some node types don't support string_content
        extract_text_content(node)
      end

      # Extract all text content from a node and its children
      # @param node [Markly::Node] The node
      # @return [String] Concatenated text content
      def extract_text_content(node)
        text_parts = []
        node.walk do |child|
          if child.type == :text
            text_parts << child.string_content.to_s
          elsif child.type == :code
            text_parts << child.string_content.to_s
          end
        end
        text_parts.join
      end

      # Get the source text for a range of lines
      # @param start_line [Integer] Start line (1-indexed)
      # @param end_line [Integer] End line (1-indexed)
      # @return [String] Source text
      def source_range(start_line, end_line)
        return "" if start_line < 1 || end_line < start_line

        @lines[(start_line - 1)..(end_line - 1)].join("\n")
      end

      private

      # Extract header content from a table node
      # @param node [Markly::Node] The table node
      # @return [String] Header row content
      def extract_table_header_content(node)
        # First row of a table is typically the header
        first_row = node.first_child
        return "" unless first_row

        extract_text_content(first_row)
      end

      # Count children of a node
      # @param node [Markly::Node] The node
      # @return [Integer] Child count
      def count_children(node)
        count = 0
        child = node.first_child
        while child
          count += 1
          child = child.next
        end
        count
      end

      # Get node name (for footnotes, etc.)
      # @param node [Markly::Node] The node
      # @return [String, nil] Node name
      def node_name(node)
        node.respond_to?(:name) ? node.name : nil
      end

      # Extract all nodes and integrate freeze blocks
      # @return [Array<Object>] Integrated list of nodes and freeze blocks
      def extract_and_integrate_all_nodes
        freeze_markers = find_freeze_markers
        return collect_top_level_nodes if freeze_markers.empty?

        # Build freeze blocks from markers
        freeze_blocks = build_freeze_blocks(freeze_markers)
        return collect_top_level_nodes if freeze_blocks.empty?

        # Integrate nodes with freeze blocks
        integrate_nodes_with_freeze_blocks(freeze_blocks)
      end

      # Collect top-level nodes from document
      # @return [Array<Markly::Node>]
      def collect_top_level_nodes
        nodes = []
        child = @document.first_child
        while child
          nodes << child
          child = child.next
        end
        nodes
      end

      # Find freeze markers in source
      # @return [Array<Hash>] Marker information
      def find_freeze_markers
        markers = []
        pattern = FreezeNode.pattern_for(:html_comment, @freeze_token)

        @lines.each_with_index do |line, index|
          match = line.match(pattern)
          next unless match

          marker_type = match[1] # "freeze" or "unfreeze"
          reason = match[2]      # optional reason

          markers << {
            line: index + 1,
            type: marker_type.to_sym,
            text: line,
            reason: reason,
          }
        end

        DebugLogger.debug("Found freeze markers", {count: markers.size})
        markers
      end

      # Build freeze blocks from markers
      # @param markers [Array<Hash>] Marker information
      # @return [Array<FreezeNodeBase>] Freeze blocks
      def build_freeze_blocks(markers)
        blocks = []
        stack = []

        markers.each do |marker|
          case marker[:type]
          when :freeze
            stack.push(marker)
          when :unfreeze
            if stack.any?
              start_marker = stack.pop
              blocks << create_freeze_block(start_marker, marker)
            else
              DebugLogger.debug("Unmatched unfreeze marker", {line: marker[:line]})
            end
          end
        end

        # Warn about unclosed freeze blocks
        stack.each do |unclosed|
          DebugLogger.debug("Unclosed freeze marker", {line: unclosed[:line]})
        end

        blocks.sort_by(&:start_line)
      end

      # Create a freeze block from start and end markers
      # @param start_marker [Hash] Start marker info
      # @param end_marker [Hash] End marker info
      # @return [FreezeNodeBase]
      def create_freeze_block(start_marker, end_marker)
        start_line = start_marker[:line]
        end_line = end_marker[:line]

        # Content is between the markers (exclusive)
        content_start = start_line + 1
        content_end = end_line - 1

        content = if content_start <= content_end
          source_range(content_start, content_end)
        else
          ""
        end

        # Parse the content to get nodes (for nested analysis)
        parsed_nodes = []
        if content.length > 0
          begin
            content_doc = Markly.parse(content, flags: @flags, extensions: @extensions)
            child = content_doc.first_child
            while child
              parsed_nodes << child
              child = child.next
            end
          rescue StandardError => e
            # :nocov: defensive - Markly.parse rarely fails on valid markdown subset
            DebugLogger.debug("Failed to parse freeze block content", {error: e.message})
            # :nocov:
          end
        end

        FreezeNode.new(
          start_line: start_line,
          end_line: end_line,
          content: content,
          start_marker: start_marker[:text],
          end_marker: end_marker[:text],
          nodes: parsed_nodes,
          reason: start_marker[:reason],
        )
      end

      # Integrate nodes with freeze blocks
      # @param freeze_blocks [Array<FreezeNodeBase>] Freeze blocks
      # @return [Array<Object>] Integrated list
      def integrate_nodes_with_freeze_blocks(freeze_blocks)
        result = []
        freeze_index = 0
        current_freeze = freeze_blocks[freeze_index]

        top_level_nodes = collect_top_level_nodes

        top_level_nodes.each do |node|
          node_start = node.source_position&.dig(:start_line) || 0
          node_end = node.source_position&.dig(:end_line) || node_start

          # Add any freeze blocks that come before this node
          while current_freeze && current_freeze.start_line < node_start
            result << current_freeze
            freeze_index += 1
            current_freeze = freeze_blocks[freeze_index]
          end

          # Skip nodes that are inside a freeze block
          inside_freeze = freeze_blocks.any? do |fb|
            node_start >= fb.start_line && node_end <= fb.end_line
          end

          result << node unless inside_freeze
        end

        # Add remaining freeze blocks
        while freeze_index < freeze_blocks.size
          result << freeze_blocks[freeze_index]
          freeze_index += 1
        end

        result
      end
    end
  end
end
