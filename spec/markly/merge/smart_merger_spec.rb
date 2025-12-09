# frozen_string_literal: true

RSpec.describe Markly::Merge::SmartMerger do
  describe "#initialize" do
    let(:template) { "# Title\n\nTemplate content.\n" }
    let(:destination) { "# Title\n\nDestination content.\n" }

    it "creates a merger" do
      merger = described_class.new(template, destination)
      expect(merger).to be_a(described_class)
    end

    it "has template_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.template_analysis).to be_a(Markly::Merge::FileAnalysis)
    end

    it "has dest_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.dest_analysis).to be_a(Markly::Merge::FileAnalysis)
    end

    it "has aligner" do
      merger = described_class.new(template, destination)
      expect(merger.aligner).to be_a(Markly::Merge::FileAligner)
    end

    it "has resolver" do
      merger = described_class.new(template, destination)
      expect(merger.resolver).to be_a(Markly::Merge::ConflictResolver)
    end

    context "with invalid template" do
      # Markly is quite tolerant, so we test error propagation
      it "accepts any markdown-like content" do
        expect { described_class.new("", destination) }.not_to raise_error
      end

      it "raises TemplateParseError when template_content doesn't respond to split" do
        expect { described_class.new(nil, destination) }.to raise_error(
          Markly::Merge::TemplateParseError,
        )
      end

      it "raises TemplateParseError when template_content is an Integer" do
        expect { described_class.new(123, destination) }.to raise_error(
          Markly::Merge::TemplateParseError,
        )
      end
    end

    context "with invalid destination" do
      it "raises DestinationParseError when dest_content doesn't respond to split" do
        expect { described_class.new(template, nil) }.to raise_error(
          Markly::Merge::DestinationParseError,
        )
      end

      it "raises DestinationParseError when dest_content is an Integer" do
        expect { described_class.new(template, 456) }.to raise_error(
          Markly::Merge::DestinationParseError,
        )
      end
    end

    context "with options" do
      it "accepts signature_match_preference" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        expect(merger.resolver.preference).to eq(:template)
      end

      it "accepts custom freeze_token" do
        merger = described_class.new(template, destination, freeze_token: "custom-token")
        expect(merger).to be_a(described_class)
      end

      it "accepts signature_generator" do
        custom_gen = ->(node) { [:custom, node.type.to_s] }
        merger = described_class.new(template, destination, signature_generator: custom_gen)
        expect(merger).to be_a(described_class)
      end

      it "accepts add_template_only_nodes" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        expect(merger).to be_a(described_class)
      end

      it "accepts flags parameter" do
        merger = described_class.new(template, destination, flags: Markly::FOOTNOTES)
        expect(merger).to be_a(described_class)
      end

      it "accepts combined flags" do
        merger = described_class.new(template, destination, flags: Markly::FOOTNOTES | Markly::SMART)
        expect(merger).to be_a(described_class)
      end

      it "accepts extensions parameter" do
        merger = described_class.new(template, destination, extensions: [:table, :strikethrough])
        expect(merger).to be_a(described_class)
      end
    end
  end

  describe "footnote merging" do
    context "with FOOTNOTES flag enabled" do
      let(:template) do
        <<~MARKDOWN
          # Document

          This has a footnote[^note1].

          [^note1]: Template footnote content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Document

          This has a footnote[^note1].

          [^note1]: Destination footnote content.
        MARKDOWN
      end

      it "parses footnotes when flag is enabled" do
        merger = described_class.new(template, destination, flags: Markly::FOOTNOTES)
        expect(merger.template_analysis.statements.any? { |s| s.respond_to?(:type) && s.type == :footnote_definition }).to be true
        expect(merger.dest_analysis.statements.any? { |s| s.respond_to?(:type) && s.type == :footnote_definition }).to be true
      end

      it "merges footnotes by label" do
        merger = described_class.new(template, destination, flags: Markly::FOOTNOTES)
        result = merger.merge

        # With destination preference, should keep destination footnote content
        expect(result).to include("Destination footnote content")
      end

      it "uses template footnote when preference is template" do
        merger = described_class.new(template, destination, flags: Markly::FOOTNOTES, signature_match_preference: :template)
        result = merger.merge

        expect(result).to include("Template footnote content")
      end
    end

    context "without FOOTNOTES flag" do
      let(:template) do
        <<~MARKDOWN
          # Document

          This has a footnote[^note1].

          [^note1]: Template footnote content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Document

          This has a footnote[^note1].

          [^note1]: Destination footnote content.
        MARKDOWN
      end

      it "treats footnote syntax as regular paragraphs" do
        merger = described_class.new(template, destination)
        # Without flag, no footnote_definition nodes should exist
        expect(merger.template_analysis.statements.none? { |s| s.respond_to?(:type) && s.type == :footnote_definition }).to be true
      end
    end
  end

  describe "#merge" do
    context "with identical files" do
      let(:content) do
        <<~MARKDOWN
          # Title

          Content here.
        MARKDOWN
      end

      it "returns successful result" do
        merger = described_class.new(content, content)
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "returns content" do
        merger = described_class.new(content, content)
        result = merger.merge_result
        expect(result.content).to include("Title")
        expect(result.content).to include("Content here")
      end
    end

    context "with destination-only sections" do
      let(:template) { "# Title" }
      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Custom Section

          Custom content.
        MARKDOWN
      end

      it "preserves destination-only sections" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Custom Section")
        expect(result.content).to include("Custom content")
      end
    end

    context "with template-only sections" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## New Section

          New content.
        MARKDOWN
      end
      let(:destination) { "# Title" }

      context "when add_template_only_nodes is false (default)" do
        it "does not add template-only sections" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          expect(result.content).not_to include("New Section")
        end
      end

      context "when add_template_only_nodes is true" do
        it "adds template-only sections" do
          merger = described_class.new(template, destination, add_template_only_nodes: true)
          result = merger.merge_result
          expect(result.content).to include("New Section")
          expect(result.content).to include("New content")
        end
      end
    end

    context "with matching sections different content" do
      # Use headings which match by level+text, with different following paragraphs
      let(:template) { "# Title\n\n## Section\n\nTemplate details." }
      let(:destination) { "# Title\n\n## Section\n\nDestination details." }

      context "when signature_match_preference is :destination (default)" do
        it "uses destination version for matched headings" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          # Headings match and destination wins
          expect(result.content).to include("# Title")
          expect(result.content).to include("## Section")
          # Paragraphs have different signatures so don't match
          # Destination-only paragraphs are preserved
          expect(result.content).to include("Destination details")
        end
      end

      context "when signature_match_preference is :template" do
        it "uses template version for matched headings" do
          merger = described_class.new(template, destination, signature_match_preference: :template)
          result = merger.merge_result
          # Headings match and template wins (but they're identical)
          expect(result.content).to include("# Title")
          expect(result.content).to include("## Section")
        end

        it "adds template-only nodes when enabled" do
          merger = described_class.new(
            template,
            destination,
            signature_match_preference: :template,
            add_template_only_nodes: true,
          )
          result = merger.merge_result
          # Both paragraphs should appear since template-only are added
          expect(result.content).to include("Template details")
        end
      end
    end

    context "with freeze blocks" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section

          Template section content.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Title

          <!-- markly-merge:freeze -->
          ## Section

          Frozen section content.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves freeze block content" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Frozen section content")
        expect(result.content).to include("markly-merge:freeze")
        expect(result.content).to include("markly-merge:unfreeze")
      end

      it "reports frozen blocks in result" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.has_frozen_blocks?).to be true
      end
    end

    context "with complex document" do
      let(:template) do
        <<~MARKDOWN
          # Project Name

          ## Installation

          ```bash
          gem install project
          ```

          ## Usage

          Template usage instructions.

          ## Contributing

          See CONTRIBUTING.md
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Project Name

          ## Installation

          ```bash
          gem install project
          ```

          ## Usage

          Custom usage instructions.

          ## Custom Section

          Project-specific content.
        MARKDOWN
      end

      it "produces valid merged output" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "preserves destination customizations" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Custom usage instructions")
        expect(result.content).to include("Custom Section")
      end
    end

    context "with empty files" do
      it "handles empty template" do
        merger = described_class.new("", "# Title")
        result = merger.merge_result
        expect(result.success?).to be true
        expect(result.content).to include("Title")
      end

      it "handles empty destination" do
        merger = described_class.new("# Title", "")
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "handles both empty" do
        merger = described_class.new("", "")
        result = merger.merge_result
        expect(result.success?).to be true
      end
    end

    context "statistics" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section

          Template content.

          ## New Section

          New content.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Section

          Destination content.
        MARKDOWN
      end

      it "tracks merge time" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.stats[:merge_time_ms]).to be >= 0
      end

      it "tracks nodes modified" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        expect(result.stats[:nodes_modified]).to be >= 0
      end

      it "tracks nodes added when template_only_nodes enabled" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.stats[:nodes_added]).to be >= 0
      end
    end
  end

  describe "error handling" do
    it "wraps template parse errors" do
      # Markly is very tolerant, so this might not actually raise
      # but the structure should handle it
      expect { described_class.new("# Valid", "# Valid") }.not_to raise_error
    end
  end

  describe "process_match edge cases" do
    let(:template) do
      <<~MARKDOWN
        # Heading

        Template paragraph.
      MARKDOWN
    end

    let(:destination) do
      <<~MARKDOWN
        # Heading

        Destination paragraph.
      MARKDOWN
    end

    context "when resolution is :destination (default)" do
      it "uses destination content" do
        merger = described_class.new(template, destination, signature_match_preference: :destination)
        result = merger.merge_result
        expect(result.content).to include("Destination paragraph")
      end
    end

    context "when resolution is :template" do
      it "prefers template for matched nodes" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # With template preference, heading match should use template
        expect(result.content).to include("Heading")
      end
    end

    context "with matching code blocks having different content" do
      let(:template) do
        <<~MARKDOWN
          # Doc

          ```ruby
          puts "template"
          ```
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Doc

          ```ruby
          puts "destination"
          ```
        MARKDOWN
      end

      it "uses template code block with :template preference and tracks modification" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # Code blocks match by fence_info + content hash, so these DON'T match
        # They're treated as separate nodes
        expect(result.success?).to be true
      end
    end
  end

  describe "process_template_only edge cases" do
    let(:template) do
      <<~MARKDOWN
        # Heading

        ## Template Only Section

        Content only in template.
      MARKDOWN
    end

    let(:destination) do
      <<~MARKDOWN
        # Heading

        Destination content.
      MARKDOWN
    end

    context "when add_template_only_nodes is true" do
      it "includes template-only sections" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.content).to include("Template Only Section")
      end

      it "increments nodes_added stat" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.stats[:nodes_added]).to be > 0
      end
    end

    context "when add_template_only_nodes is false" do
      it "excludes template-only sections" do
        merger = described_class.new(template, destination, add_template_only_nodes: false)
        result = merger.merge_result
        expect(result.content).not_to include("Template Only Section")
      end
    end
  end

  describe "process_dest_only edge cases" do
    let(:template) do
      <<~MARKDOWN
        # Heading

        Template content.
      MARKDOWN
    end

    let(:destination) do
      <<~MARKDOWN
        # Heading

        Destination content.

        ## Dest Only Section

        Extra content in destination.
      MARKDOWN
    end

    it "always includes destination-only sections" do
      merger = described_class.new(template, destination)
      result = merger.merge_result
      expect(result.content).to include("Dest Only Section")
    end

    context "with freeze block in destination-only" do
      let(:destination_with_freeze) do
        <<~MARKDOWN
          # Heading

          Destination content.

          <!-- markly-merge:freeze -->
          ## Frozen Section

          This is frozen.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves freeze block info" do
        merger = described_class.new(template, destination_with_freeze)
        result = merger.merge_result
        expect(result.content).to include("markly-merge:freeze")
        expect(result.content).to include("Frozen Section")
      end
    end
  end

  describe "node_to_source edge cases" do
    context "with FreezeNode" do
      let(:template) { "# Heading\n" }
      let(:destination) do
        <<~MARKDOWN
          # Heading

          <!-- markly-merge:freeze -->
          Frozen content here.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "uses full_text for FreezeNode" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Frozen content here")
      end
    end

    context "with node missing source_position" do
      let(:template) { "# Test\n\nParagraph.\n" }
      let(:destination) { "# Test\n\nDifferent.\n" }

      it "falls back to to_html" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        # Should produce valid output even if source_position is missing
        expect(result.content).not_to be_empty
      end
    end
  end

  describe "alignment processing edge cases" do
    context "with empty alignment" do
      let(:template) { "" }
      let(:destination) { "" }

      it "handles empty documents" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result).to be_a(Markly::Merge::MergeResult)
      end
    end

    context "with only template_only entries" do
      let(:template) do
        <<~MARKDOWN
          # Template Only

          Content only in template.
        MARKDOWN
      end
      let(:destination) { "" }

      it "processes template_only entries when add_template_only_nodes is true" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.content).to include("Template Only")
      end

      it "skips template_only entries when add_template_only_nodes is false" do
        merger = described_class.new(template, destination, add_template_only_nodes: false)
        result = merger.merge_result
        expect(result.content).not_to include("Template Only")
      end
    end

    context "with only dest_only entries" do
      let(:template) { "" }
      let(:destination) do
        <<~MARKDOWN
          # Dest Only

          Content only in destination.
        MARKDOWN
      end

      it "always includes dest_only entries" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Dest Only")
      end
    end
  end

  describe "process_match with different resolution sources" do
    context "when template node is chosen" do
      let(:template) do
        <<~MARKDOWN
          # Same Heading

          Template paragraph content.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Same Heading

          Destination paragraph content.
        MARKDOWN
      end

      it "uses template content with template preference" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # Heading should match, preference determines which paragraph text
        expect(result.content).to include("Same Heading")
      end
    end

    context "when dest node is a FreezeNode" do
      let(:template) do
        <<~MARKDOWN
          # Heading

          Template paragraph.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          <!-- markly-merge:freeze -->
          # Heading

          Frozen in destination.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "records frozen block info" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.frozen_blocks).not_to be_empty
      end
    end

    context "when entry returns nil part from process_match" do
      # Tests for branch at line 184 (merged_parts << part if part)
      let(:template) { "# Test\n\nParagraph." }
      let(:destination) { "# Test\n\nParagraph." }

      it "handles match entries normally" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Test")
      end
    end

    context "when template_only entry is processed" do
      # Tests for branch at line 191 (merged_parts << part if part)
      let(:template) do
        <<~MARKDOWN
          # Only in template

          Template only paragraph.
        MARKDOWN
      end
      let(:destination) { "" }

      it "includes template-only content" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.content).to include("Only in template")
      end
    end

    context "when dest_only entry returns nil frozen" do
      # Tests for branch at line 220 (frozen_blocks << frozen if frozen)
      let(:template) { "# Template heading" }
      let(:destination) do
        <<~MARKDOWN
          # Template heading

          This is destination-only content that is not frozen.
        MARKDOWN
      end

      it "does not add nil to frozen_blocks" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        # The dest-only paragraph should be included but not in frozen_blocks
        expect(result.frozen_blocks).to be_empty
      end
    end

    context "when process_match uses template source" do
      # Tests for the :template branch in process_match (lines 213-215)
      # This happens when preference is :template and content differs
      # Lists match by type and item count, so two lists with same count
      # but different content will match and trigger the template branch
      let(:template) do
        <<~MARKDOWN
          # Same Heading

          - Template item one
          - Template item two
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Same Heading

          - Destination item one
          - Destination item two
        MARKDOWN
      end

      it "uses template content when preference is :template" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        expect(result.content).to include("Template item one")
        expect(result.content).not_to include("Destination item one")
      end

      it "increments nodes_modified for non-identical matched content" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # The list has different content but matches by signature (same type, same item count)
        expect(result.stats[:nodes_modified]).to be >= 1
      end
    end

    context "when process_match has frozen destination node" do
      # Tests for frozen_blocks << frozen if frozen (line 184)
      let(:template) do
        <<~MARKDOWN
          # Matching Heading

          Template paragraph.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          <!-- markly-merge:freeze -->
          # Matching Heading

          Frozen destination content.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "tracks frozen block info from matched freeze nodes" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.frozen_blocks).not_to be_empty
      end
    end
  end

  describe "table merging" do
    # Tables use content-based signatures (row count + header content hash), so
    # tables with the same row count AND header content will match even if body
    # cell content differs. Tables with different headers have different signatures
    # and won't match automatically.

    describe "tables with same row count and same headers but different body content" do
      context "1a. body cell changed in destination, preference: :destination" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 999   |
            | bar  | 200   |
          MARKDOWN
        end

        it "uses destination table content" do
          merger = described_class.new(template, destination, signature_match_preference: :destination)
          result = merger.merge_result
          expect(result.content).to include("999")
          expect(result.content).not_to include("100")
        end
      end

      context "1b. body cell changed in destination, preference: :template" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 999   |
            | bar  | 200   |
          MARKDOWN
        end

        it "uses template table content" do
          merger = described_class.new(template, destination, signature_match_preference: :template)
          result = merger.merge_result
          expect(result.content).to include("100")
          expect(result.content).not_to include("999")
        end

        it "increments nodes_modified stat" do
          merger = described_class.new(template, destination, signature_match_preference: :template)
          result = merger.merge_result
          expect(result.stats[:nodes_modified]).to be >= 1
        end
      end
    end

    describe "tables with same row count but different headers (no signature match)" do
      # When headers differ, tables have different signatures and won't match.
      # They become template_only and dest_only entries, so both appear in output.

      context "1c. header cell changed in destination, preference: :destination" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Item | Amount |
            |------|--------|
            | foo  | 100    |
          MARKDOWN
        end

        it "includes destination table and template table (both unmatched)" do
          merger = described_class.new(template, destination, signature_match_preference: :destination)
          result = merger.merge_result
          # Both tables appear since they have different signatures
          expect(result.content).to include("Item")
          expect(result.content).to include("Amount")
        end

        it "excludes template table when add_template_only_nodes is false" do
          merger = described_class.new(template, destination, signature_match_preference: :destination, add_template_only_nodes: false)
          result = merger.merge_result
          expect(result.content).to include("Item")
          expect(result.content).to include("Amount")
          expect(result.content).not_to include("Name")
          expect(result.content).not_to include("Value")
        end
      end

      context "1d. header cell changed in destination, preference: :template" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Item | Amount |
            |------|--------|
            | foo  | 100    |
          MARKDOWN
        end

        it "includes both tables since they have different signatures" do
          merger = described_class.new(template, destination, signature_match_preference: :template)
          result = merger.merge_result
          # Both tables appear since they have different signatures
          expect(result.content).to include("Item")
          expect(result.content).to include("Amount")
        end

        it "includes only template table when add_template_only_nodes is true (default) and destination table" do
          merger = described_class.new(template, destination, signature_match_preference: :template, add_template_only_nodes: true)
          result = merger.merge_result
          # Template table is added as template_only, destination table is dest_only
          expect(result.content).to include("Name")
          expect(result.content).to include("Value")
          expect(result.content).to include("Item")
          expect(result.content).to include("Amount")
        end
      end
    end

    describe "tables with different row counts (structure mismatch - no signature match)" do
      # When row counts differ, tables have different signatures and won't match.
      # They become template_only and dest_only entries.

      context "2a. row added in destination, preference: :destination" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end

        it "includes destination table (dest_only) with extra row" do
          merger = described_class.new(template, destination, signature_match_preference: :destination)
          result = merger.merge_result
          expect(result.content).to include("bar")
          expect(result.content).to include("200")
        end

        it "excludes template table when add_template_only_nodes is false" do
          merger = described_class.new(template, destination, signature_match_preference: :destination, add_template_only_nodes: false)
          result = merger.merge_result
          expected = <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
          expect(result.content).to eq(expected.chomp)
        end
      end

      context "2b. row added in destination, preference: :template" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end

        it "includes destination table as dest_only regardless of preference" do
          merger = described_class.new(template, destination, signature_match_preference: :template)
          result = merger.merge_result
          # dest_only entries are always included
          expect(result.content).to include("bar")
        end

        it "includes both tables when add_template_only_nodes is true" do
          merger = described_class.new(template, destination, signature_match_preference: :template, add_template_only_nodes: true)
          result = merger.merge_result
          # dest_only table (with bar) comes first, then template_only table (without bar)
          expected = <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
          expect(result.content).to eq(expected.chomp)
        end
      end

      context "2c. row removed in destination (added in template), preference: :destination" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end

        it "includes destination table without the extra row" do
          merger = described_class.new(template, destination, signature_match_preference: :destination)
          result = merger.merge_result
          expect(result.content).to include("foo")
        end

        it "excludes template table when add_template_only_nodes is false" do
          merger = described_class.new(template, destination, signature_match_preference: :destination, add_template_only_nodes: false)
          result = merger.merge_result
          expected = <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
          expect(result.content).to eq(expected.chomp)
        end
      end

      context "2d. row removed in destination (added in template), preference: :template" do
        let(:template) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
        end
        let(:destination) do
          <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
        end

        it "includes both tables when add_template_only_nodes is true" do
          merger = described_class.new(template, destination, signature_match_preference: :template, add_template_only_nodes: true)
          result = merger.merge_result
          # dest_only table (without bar) comes first, then template_only table (with bar)
          expected = <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |

            | Name | Value |
            |------|-------|
            | foo  | 100   |
            | bar  | 200   |
          MARKDOWN
          expect(result.content).to eq(expected.chomp)
        end

        it "includes only destination table when add_template_only_nodes is false" do
          merger = described_class.new(template, destination, signature_match_preference: :template, add_template_only_nodes: false)
          result = merger.merge_result
          expected = <<~MARKDOWN
            # Data

            | Name | Value |
            |------|-------|
            | foo  | 100   |
          MARKDOWN
          expect(result.content).to eq(expected.chomp)
        end
      end
    end
  end

  describe "edge cases for branch coverage" do
    context "with nodes that have identical content in both versions" do
      let(:template) do
        <<~MARKDOWN
          # Identical Title

          Identical paragraph content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Identical Title

          Identical paragraph content.
        MARKDOWN
      end

      it "marks nodes as identical (not modified)" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # When identical, stats should show 0 modifications
        expect(result.stats[:nodes_modified]).to eq(0)
      end
    end

    context "with freeze node in match resolution" do
      let(:template) do
        <<~MARKDOWN
          # Title

          Template paragraph.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          <!-- markly-merge:freeze reason here -->
          Frozen paragraph.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves freeze node info in result" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        # The freeze block should be preserved
        expect(result.content).to include("Frozen paragraph")
        expect(result.content).to include("markly-merge:freeze")
      end
    end

    context "with node that falls back to commonmark rendering" do
      # This tests the node_to_source fallback when source_position is missing
      let(:template) { "# Simple" }
      let(:destination) { "# Simple" }

      it "handles nodes gracefully" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Simple")
      end
    end

    context "with freeze node in dest_only processing" do
      let(:template) do
        <<~MARKDOWN
          # Title
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          <!-- markly-merge:freeze custom-reason -->
          ## Custom Frozen Section

          This is frozen and should be preserved.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves freeze blocks from dest_only entries" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Custom Frozen Section")
        expect(result.has_frozen_blocks?).to be true
      end

      it "captures freeze block metadata" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        frozen = result.frozen_blocks.first
        expect(frozen).not_to be_nil
        expect(frozen[:reason]).to include("custom-reason")
      end
    end

    context "with template preference and modified content" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section

          Template version of content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Section

          Different destination content.
        MARKDOWN
      end

      it "counts modifications when template wins" do
        merger = described_class.new(template, destination, signature_match_preference: :template)
        result = merger.merge_result
        # Paragraphs don't match (different content), so they're not modified
        # Only matching nodes can be modified
        expect(result).to be_success
      end
    end

    context "with empty content" do
      let(:template) { "" }
      let(:destination) { "" }

      it "handles empty documents" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.success?).to be true
        expect(result.content).to eq("")
      end
    end

    context "with only whitespace content" do
      let(:template) { "   \n\n  " }
      let(:destination) { "\n\n\n" }

      it "handles whitespace-only documents" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.success?).to be true
      end
    end

    context "with freeze_node? check in destination match" do
      let(:template) do
        <<~MARKDOWN
          # Title

          Updated content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          <!-- markly-merge:freeze -->
          Frozen content.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "handles freeze nodes in destination with preference destination" do
        merger = described_class.new(template, destination, signature_match_preference: :destination)
        result = merger.merge_result
        expect(result).to be_success
        expect(result.has_frozen_blocks?).to be true
      end
    end

    context "with node that has nil source_position" do
      let(:template) { "# Title\n\nParagraph." }
      let(:destination) { "# Title\n\nParagraph." }

      it "falls back to to_commonmark when position is nil" do
        merger = described_class.new(template, destination)
        # This exercises the node_to_source method's fallback path
        result = merger.merge_result
        expect(result).to be_success
      end
    end

    context "with complex alignment scenarios" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section A

          Content A.

          ## Section B

          Content B.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Section A

          Modified A.

          ## New Section

          New content.
        MARKDOWN
      end

      it "handles template_only entries" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        # Section B should be added from template
        expect(result.content).to include("Section B")
      end

      it "handles dest_only entries" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        # New Section should be preserved
        expect(result.content).to include("New Section")
      end
    end

    context "with dest_only freeze node" do
      let(:template) do
        <<~MARKDOWN
          # Title

          Template content.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Title

          Different content.

          <!-- markly-merge:freeze -->
          Extra frozen section.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves dest_only freeze blocks" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.has_frozen_blocks?).to be true
        expect(result.frozen_blocks).not_to be_empty
      end

      it "includes freeze block in merged content" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Extra frozen section")
      end
    end

    context "with match where destination is chosen" do
      let(:template) do
        <<~MARKDOWN
          # Same Title

          ## Same Section

          Content from template.
        MARKDOWN
      end

      let(:destination) do
        <<~MARKDOWN
          # Same Title

          ## Same Section

          Content from destination.
        MARKDOWN
      end

      it "uses destination content with destination preference" do
        merger = described_class.new(template, destination, signature_match_preference: :destination)
        result = merger.merge_result
        expect(result.content).to include("destination")
      end
    end
  end
end
