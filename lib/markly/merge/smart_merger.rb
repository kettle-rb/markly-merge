# frozen_string_literal: true

module Markly
  module Merge
    # Orchestrates the smart merge process for Markdown files.
    #
    # Uses FileAnalysis, FileAligner, ConflictResolver, and MergeResult to
    # merge two Markdown files intelligently. Freeze blocks marked with
    # HTML comments are preserved exactly as-is.
    #
    # SmartMerger provides flexible configuration for different merge scenarios:
    # - Preserve destination customizations (default)
    # - Apply template updates
    # - Add new sections from template
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
    #     signature_match_preference: :template,
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
    # @see FileAnalysis
    # @see FileAligner
    # @see ConflictResolver
    # @see MergeResult
    class SmartMerger
      # @return [FileAnalysis] Analysis of the template file
      attr_reader :template_analysis

      # @return [FileAnalysis] Analysis of the destination file
      attr_reader :dest_analysis

      # @return [FileAligner] Aligner for finding matches and differences
      attr_reader :aligner

      # @return [ConflictResolver] Resolver for handling conflicting content
      attr_reader :resolver

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
      # @param signature_match_preference [Symbol] Controls which version to use when nodes
      #   have matching signatures but different content:
      #   - `:destination` (default) - Use destination version (preserves customizations)
      #   - `:template` - Use template version (applies updates)
      #
      # @param add_template_only_nodes [Boolean] Controls whether to add nodes that only
      #   exist in template:
      #   - `false` (default) - Skip template-only nodes
      #   - `true` - Add template-only nodes to result
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
        signature_match_preference: :destination,
        add_template_only_nodes: false,
        freeze_token: FileAnalysis::DEFAULT_FREEZE_TOKEN,
        flags: Markly::DEFAULT,
        extensions: [:table],
        match_refiner: nil
      )
        @signature_match_preference = signature_match_preference
        @add_template_only_nodes = add_template_only_nodes
        @match_refiner = match_refiner

        # Parse template
        begin
          @template_analysis = FileAnalysis.new(
            template_content,
            freeze_token: freeze_token,
            signature_generator: signature_generator,
            flags: flags,
            extensions: extensions,
          )
        rescue StandardError => e
          raise TemplateParseError.new(errors: [e])
        end

        # Parse destination
        begin
          @dest_analysis = FileAnalysis.new(
            dest_content,
            freeze_token: freeze_token,
            signature_generator: signature_generator,
            flags: flags,
            extensions: extensions,
          )
        rescue StandardError => e
          raise DestinationParseError.new(errors: [e])
        end

        @aligner = FileAligner.new(@template_analysis, @dest_analysis, match_refiner: @match_refiner)
        @resolver = ConflictResolver.new(
          preference: @signature_match_preference,
          template_analysis: @template_analysis,
          dest_analysis: @dest_analysis,
        )
      end

      # Perform the merge operation and return the merged content as a string.
      #
      # @return [String] The merged Markdown content
      def merge
        merge_result.content
      end

      # Perform the merge operation and return the full MergeResult object.
      #
      # @return [MergeResult] The merge result containing merged content and metadata
      def merge_result
        return @merge_result if @merge_result

        @merge_result = DebugLogger.time("SmartMerger#merge") do
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          alignment = DebugLogger.time("SmartMerger#align") do
            @aligner.align
          end

          DebugLogger.debug("Alignment complete", {
            total_entries: alignment.size,
            matches: alignment.count { |e| e[:type] == :match },
            template_only: alignment.count { |e| e[:type] == :template_only },
            dest_only: alignment.count { |e| e[:type] == :dest_only },
          })

          merged_parts, stats, frozen_blocks, conflicts = DebugLogger.time("SmartMerger#process") do
            process_alignment(alignment)
          end

          end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          stats[:merge_time_ms] = ((end_time - start_time) * 1000).round(2)

          MergeResult.new(
            content: merged_parts.join("\n\n"),
            conflicts: conflicts,
            frozen_blocks: frozen_blocks,
            stats: stats,
          )
        end
      end

      private

      # Process alignment entries and build result
      #
      # @param alignment [Array<Hash>] Alignment entries
      # @return [Array] [merged_parts, stats, frozen_blocks, conflicts]
      def process_alignment(alignment)
        merged_parts = []
        frozen_blocks = []
        conflicts = []
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}

        alignment.each do |entry|
          case entry[:type]
          when :match
            part, frozen = process_match(entry, stats)
            merged_parts << part if part
            frozen_blocks << frozen if frozen
          when :template_only
            part = process_template_only(entry, stats)
            merged_parts << part if part
          when :dest_only
            part, frozen = process_dest_only(entry, stats)
            merged_parts << part if part
            frozen_blocks << frozen if frozen
          end
        end

        [merged_parts, stats, frozen_blocks, conflicts]
      end

      # Process a matched node pair
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [Array] [content_string, frozen_block_info]
      def process_match(entry, stats)
        resolution = @resolver.resolve(
          entry[:template_node],
          entry[:dest_node],
          template_index: entry[:template_index],
          dest_index: entry[:dest_index],
        )

        frozen_info = nil

        content = case resolution[:source]
        when :template
          stats[:nodes_modified] += 1 if resolution[:decision] != :identical
          node_to_source(entry[:template_node], @template_analysis)
        when :destination
          if entry[:dest_node].respond_to?(:freeze_node?) && entry[:dest_node].freeze_node?
            frozen_info = {
              start_line: entry[:dest_node].start_line,
              end_line: entry[:dest_node].end_line,
              reason: entry[:dest_node].reason,
            }
          end
          node_to_source(entry[:dest_node], @dest_analysis)
        end

        [content, frozen_info]
      end

      # Process a template-only node
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [String, nil] Content string or nil
      def process_template_only(entry, stats)
        return unless @add_template_only_nodes

        stats[:nodes_added] += 1
        node_to_source(entry[:template_node], @template_analysis)
      end

      # Process a destination-only node
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [Array] [content_string, frozen_block_info]
      def process_dest_only(entry, stats)
        frozen_info = nil

        if entry[:dest_node].respond_to?(:freeze_node?) && entry[:dest_node].freeze_node?
          frozen_info = {
            start_line: entry[:dest_node].start_line,
            end_line: entry[:dest_node].end_line,
            reason: entry[:dest_node].reason,
          }
        end

        content = node_to_source(entry[:dest_node], @dest_analysis)
        [content, frozen_info]
      end

      # Convert a node to its source text
      #
      # @param node [Object] Node to convert
      # @param analysis [FileAnalysis] Analysis for source lookup
      # @return [String] Source text
      def node_to_source(node, analysis)
        case node
        when FreezeNode
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
