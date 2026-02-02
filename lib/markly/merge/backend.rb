# frozen_string_literal: true

module Markly
  module Merge
    # Markly backend using the Markly gem (cmark-gfm C library)
    #
    # This backend wraps Markly, a Ruby gem that provides bindings to
    # cmark-gfm, GitHub's fork of the CommonMark C library with extensions.
    #
    # @note This backend only parses Markdown source code
    # @see https://github.com/ioquatix/markly Markly gem
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = Markly::Merge::Backend::Language.markdown(
    #     flags: Markly::DEFAULT,
    #     extensions: [:table, :strikethrough]
    #   )
    #   tree = parser.parse(markdown_source)
    #   root = tree.root_node
    #   puts root.type  # => "document"
    module Backend
      @load_attempted = false
      @loaded = false

      # Check if the Markly backend is available
      #
      # @return [Boolean] true if markly gem is available
      class << self
        def available?
          return @loaded if @load_attempted # rubocop:disable ThreadSafety/ClassInstanceVariable
          @load_attempted = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          begin
            require "markly"
            @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue LoadError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue StandardError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          end
          @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Reset the load state (primarily for testing)
        #
        # @return [void]
        # @api private
        def reset!
          @load_attempted = false
          @loaded = false
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        def capabilities
          return {} unless available?
          {
            backend: :markly,
            query: false,
            bytes_field: false,       # Markly uses line/column
            incremental: false,
            pure_ruby: false,         # Uses C via FFI
            markdown_only: true,
            error_tolerant: true,     # Markdown is forgiving
            gfm_extensions: true,     # Supports GitHub Flavored Markdown
          }
        end
      end

      # Markly language wrapper
      #
      # Markly only parses Markdown. This class exists for API compatibility
      # and to pass through Markly-specific options (flags, extensions).
      #
      # @example
      #   language = Markly::Merge::Backend::Language.markdown(
      #     flags: Markly::DEFAULT | Markly::FOOTNOTES,
      #     extensions: [:table, :strikethrough]
      #   )
      #   parser.language = language
      class Language < ::TreeHaver::Base::Language
        # Markly parse flags
        # @return [Integer]
        attr_reader :flags

        # Markly extensions to enable
        # @return [Array<Symbol>]
        attr_reader :extensions

        # Create a new Markly language instance
        #
        # @param name [Symbol] Language name (should be :markdown)
        # @param flags [Integer] Markly parse flags (default: Markly::DEFAULT)
        # @param extensions [Array<Symbol>] Extensions to enable (default: [:table])
        # @param options [Hash] parsing options (reserved for future use)
        def initialize(name = :markdown, flags: nil, extensions: [:table], options: {})
          super(name, backend: :markly, options: options.merge({flags: flags, extensions: extensions}))
          @flags = flags  # Will use Markly::DEFAULT if nil at parse time
          @extensions = extensions

          unless @name == :markdown
            raise TreeHaver::NotAvailable,
                  "Markly backend only supports Markdown parsing. " \
                    "Got language: #{name.inspect}"
          end
        end

        class << self
          # Create a Markdown language instance
          #
          # @param flags [Integer] Markly parse flags
          # @param extensions [Array<Symbol>] Extensions to enable
          # @param options [Hash] parsing options (reserved for future use)
          # @return [Language] Markdown language
          def markdown(flags: nil, extensions: [:table], options: {})
            new(:markdown, flags: flags, extensions: extensions, options: options)
          end

          # Load language from library path (API compatibility)
          #
          # @param _path [String] Ignored - Markly doesn't load external grammars
          # @param symbol [String, nil] Ignored
          # @param name [String, nil] Language name hint (defaults to :markdown)
          # @return [Language] Markdown language
          # @raise [TreeHaver::NotAvailable] if requested language is not Markdown
          def from_library(_path = nil, symbol: nil, name: nil)
            lang_name = name || symbol&.to_s&.sub(/^tree_sitter_/, "")&.to_sym || :markdown

            unless lang_name == :markdown
              raise TreeHaver::NotAvailable,
                "Markly backend only supports Markdown, not #{lang_name}. " \
                  "Use a tree-sitter backend for #{lang_name} support."
            end

            markdown
          end
        end
      end

      # Markly parser wrapper
      class Parser < ::TreeHaver::Base::Parser
        # Create a new RBS parser instance
        #
        # @raise [TreeHaver::NotAvailable] if rbs gem is not available
        def initialize
          super()
          raise TreeHaver::NotAvailable, "markly gem not available" unless Backend.available?
        end

        # Set the language for this parser
        #
        # @param lang [Language, Symbol] RBS language (should be :rbs or Language instance)
        # @return [void]
        def language=(lang)
          case lang
          when Language
            @language = lang
          when Symbol, String
            if lang.to_sym == :markdown
              @language = Language.markdown
            else
              raise ArgumentError,
                    "Markly backend only supports Markdown parsing. Got: #{lang.inspect}"
            end
          else
            raise ArgumentError,
                  "Expected Backend::Language or :markdown, got #{lang.class}"
          end
        end

        # Parse Markdown source code
        #
        # @param source [String] Markdown source to parse
        # @return [Tree] Parsed tree
        def parse(source)
          raise "Language not set" unless language
          Backend.available? or raise "Markly not available"

          flags = language.flags || ::Markly::DEFAULT
          exts = language.extensions || [:table]
          doc = ::Markly.parse(source, flags: flags, extensions: exts)
          Tree.new(doc, source)
        end
      end

      # Markly tree wrapper
      #
      # Wraps Markly parse results to provide tree-sitter-compatible API.
      #
      # @api private
      class Tree < ::TreeHaver::Base::Tree
        def initialize(document, source)
          super(document, source: source)
        end

        def root_node
          Node.new(inner_tree, source: source, lines: lines)
        end
      end

      # Markly node wrapper
      #
      # Wraps Markly::Node to provide TreeHaver::Node-compatible interface.
      class Node < ::TreeHaver::Base::Node
        # Type normalization map (Markly → canonical)
        TYPE_MAP = {
          header: "heading",
          hrule: "thematic_break",
          html: "html_block",
        }.freeze

        # Default source position for nodes that don't have position info
        DEFAULT_SOURCE_POSITION = {
          start_line: 1,
          start_column: 1,
          end_line: 1,
          end_column: 1,
        }.freeze

        # Get source position from the inner Markly node
        #
        # @return [Hash{Symbol => Integer}] Source position from Markly
        # @api private
        def inner_source_position
          @inner_source_position ||= if inner_node.respond_to?(:source_position)
            inner_node.source_position || DEFAULT_SOURCE_POSITION
          else
            DEFAULT_SOURCE_POSITION
          end
        end

        # Get the node type as a string (normalized)
        #
        # @return [String] Node type
        def type
          raw = inner_node.type.to_s
          TYPE_MAP[raw.to_sym]&.to_s || raw
        end

        # Get the raw (non-normalized) type
        # @return [String]
        def raw_type
          inner_node.type.to_s
        end

        # Get the text content of this node
        #
        # @return [String] Node text
        def text
          if inner_node.respond_to?(:string_content)
            content = inner_node.string_content.to_s
            return content unless content.empty?
          end

          if inner_node.respond_to?(:to_plaintext)
            inner_node.to_plaintext rescue children.map(&:text).join
          else
            children.map(&:text).join
          end
        end

        # Get child nodes (Markly uses first_child/next pattern)
        #
        # @return [Array<Node>] Child nodes
        def children
          result = []
          child = inner_node.first_child rescue nil
          while child
            result << Node.new(child, source: source, lines: lines)
            child = child.next rescue nil
          end
          result
        end

        # Position information

        def start_byte
          pos = inner_source_position
          calculate_byte_offset(pos[:start_line] - 1, pos[:start_column] - 1)
        end

        def end_byte
          pos = inner_source_position
          calculate_byte_offset(pos[:end_line] - 1, pos[:end_column] - 1)
        end

        def start_point
          pos = inner_source_position
          {row: pos[:start_line] - 1, column: pos[:start_column] - 1}
        end

        def end_point
          pos = inner_source_position
          {row: pos[:end_line] - 1, column: pos[:end_column] - 1}
        end

        # Convert node to CommonMark/Markdown/HTML/plaintext
        def to_commonmark
          inner_node.to_commonmark
        end

        def to_markdown
          inner_node.to_markdown
        end

        def to_plaintext
          inner_node.to_plaintext
        end

        def to_html
          inner_node.to_html
        end

        # Markly-specific methods

        # Get heading level (1-6)
        # @return [Integer, nil]
        def header_level
          return unless raw_type == "header"
          inner_node.header_level rescue nil
        end

        # Get fence info for code blocks
        # @return [String, nil]
        def fence_info
          return unless type == "code_block"
          inner_node.fence_info rescue nil
        end

        # Get URL for links/images
        # @return [String, nil]
        def url
          inner_node.url rescue nil
        end

        # Get title for links/images
        # @return [String, nil]
        def title
          inner_node.title rescue nil
        end

        # Get the next sibling (Markly uses .next)
        # @return [Node, nil]
        def next_sibling
          sibling = inner_node.next rescue nil
          sibling ? Node.new(sibling, source: source, lines: lines) : nil
        end

        # Get the previous sibling
        # @return [Node, nil]
        def prev_sibling
          sibling = inner_node.previous rescue nil
          sibling ? Node.new(sibling, source: source, lines: lines) : nil
        end

        # Get the parent node
        # @return [Node, nil]
        def parent
          p = inner_node.parent rescue nil
          p ? Node.new(p, source: source, lines: lines) : nil
        end
      end

      # Alias Point to the base class for compatibility
      Point = ::TreeHaver::Base::Point

      # Register this backend with TreeHaver
      ::TreeHaver.register_language(
        :markdown,
        backend_type: :markly,
        backend_module: self,
        gem_name: "markly"
      )

      # Register the full tag for RSpec dependency tags with require path
      # This enables tree_haver to lazily load this gem when checking availability
      ::TreeHaver::BackendRegistry.register_tag(
        :markly_backend,
        category: :backend,
        backend_name: :markly,
        require_path: "markly/merge"
      ) { available? }
    end
  end
end
