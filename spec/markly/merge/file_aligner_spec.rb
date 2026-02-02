# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markly::Merge::FileAligner do
  let(:template_source) do
    <<~MARKDOWN
      # Title

      Template paragraph.

      ## Section One

      Template section content.
    MARKDOWN
  end

  let(:dest_source) do
    <<~MARKDOWN
      # Title

      Destination paragraph.

      ## Section One

      Destination section content.
    MARKDOWN
  end

  let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_source) }
  let(:dest_analysis) { Markly::Merge::FileAnalysis.new(dest_source) }

  describe "#initialize" do
    it "creates an aligner with analyses" do
      aligner = described_class.new(template_analysis, dest_analysis)
      expect(aligner.template_analysis).to eq(template_analysis)
      expect(aligner.dest_analysis).to eq(dest_analysis)
    end
  end

  describe "#align" do
    context "with matching structures" do
      it "returns alignment entries" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align
        expect(alignment).to be_an(Array)
        expect(alignment).not_to be_empty
      end

      it "creates match entries for matching nodes" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align
        matches = alignment.select { |e| e[:type] == :match }
        expect(matches).not_to be_empty
      end

      it "includes template and destination nodes in matches" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align
        match = alignment.find { |e| e[:type] == :match }
        expect(match).to have_key(:template_node)
        expect(match).to have_key(:dest_node)
      end
    end

    context "with template-only nodes" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          ## Section One

          ## Section Two
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          ## Section One
        MARKDOWN
      end

      it "creates template_only entries" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        template_only = alignment.select { |e| e[:type] == :template_only }
        expect(template_only).not_to be_empty
      end

      it "includes template node and index in template_only" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        template_only = alignment.find { |e| e[:type] == :template_only }
        expect(template_only).to have_key(:template_node)
        expect(template_only).to have_key(:template_index)
      end
    end

    context "with destination-only nodes" do
      let(:template_source) do
        <<~MARKDOWN
          # Title
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          ## Custom Section

          Custom content.
        MARKDOWN
      end

      it "creates dest_only entries" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        dest_only = alignment.select { |e| e[:type] == :dest_only }
        expect(dest_only).not_to be_empty
      end

      it "includes dest node and index in dest_only" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        dest_only = alignment.find { |e| e[:type] == :dest_only }
        expect(dest_only).to have_key(:dest_node)
        expect(dest_only).to have_key(:dest_index)
      end
    end

    context "with freeze blocks" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          Template paragraph.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          <!-- markly-merge:freeze -->
          ## Frozen Section

          Frozen content.
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end

      it "includes freeze blocks in alignment" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align

        # The freeze block should appear as dest_only
        dest_only = alignment.select { |e| e[:type] == :dest_only }
        freeze_entry = dest_only.find { |e| e[:dest_node].is_a?(Markly::Merge::FreezeNode) }
        expect(freeze_entry).not_to be_nil
      end
    end

    context "with empty files" do
      it "handles empty template" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(""),
          Markly::Merge::FileAnalysis.new("# Title"),
        )
        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end

      it "handles empty destination" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new("# Title"),
          Markly::Merge::FileAnalysis.new(""),
        )
        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end

      it "handles both empty" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(""),
          Markly::Merge::FileAnalysis.new(""),
        )
        alignment = aligner.align
        expect(alignment).to be_empty
      end
    end

    context "with reordered content" do
      let(:template_source) do
        <<~MARKDOWN
          ## Section A

          ## Section B

          ## Section C
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          ## Section C

          ## Section A

          ## Section B
        MARKDOWN
      end

      it "matches sections by signature regardless of order" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        matches = alignment.select { |e| e[:type] == :match }
        # Filter out gap_line matches to count only heading matches
        heading_matches = matches.reject { |e|
          node = e[:template_node] || e[:dest_node]
          node.respond_to?(:type) && (node.type == :gap_line || node.type == "gap_line")
        }
        # All sections should match
        expect(heading_matches.size).to eq(3)
      end
    end
  end

  describe "signature matching" do
    context "with matching headings" do
      let(:template_source) { "# Same Title" }
      let(:dest_source) { "# Same Title" }

      it "matches headings with same content" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        expect(alignment.first[:type]).to eq(:match)
      end
    end

    context "with different heading levels" do
      let(:template_source) { "# Title" }
      let(:dest_source) { "## Title" }

      it "does not match different levels" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        # Should have template_only and dest_only, not a match
        types = alignment.map { |e| e[:type] }
        expect(types).not_to include(:match)
      end
    end

    context "with code blocks" do
      let(:template_source) do
        <<~MARKDOWN
          ```ruby
          puts "hello"
          ```
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          ```ruby
          puts "hello"
          ```
        MARKDOWN
      end

      it "matches code blocks with same language and content" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        expect(alignment.first[:type]).to eq(:match)
      end
    end

    context "with code blocks different content" do
      let(:template_source) do
        <<~MARKDOWN
          ```ruby
          puts "template"
          ```
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          ```ruby
          puts "dest"
          ```
        MARKDOWN
      end

      it "does not match code blocks with different content" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align
        # Filter out gap_line matches - we're testing code block matching
        code_block_entries = alignment.reject { |e|
          node = e[:template_node] || e[:dest_node]
          node.is_a?(Markdown::Merge::GapLineNode) ||
            (node.respond_to?(:type) && (node.type == :gap_line || node.type == "gap_line"))
        }
        # Different content = different signatures = no match for code blocks
        types = code_block_entries.map { |e| e[:type] }
        expect(types).not_to include(:match)
      end
    end
  end

  describe "#align sorting edge cases" do
    # Lines 113, 145: sort_by branches for different entry types
    context "with all alignment types" do
      let(:template_analysis) do
        Markly::Merge::FileAnalysis.new(<<~MARKDOWN)
          # Common Heading

          Template unique paragraph.

          ## Template Only Section

          Template section content.
        MARKDOWN
      end

      let(:dest_analysis) do
        Markly::Merge::FileAnalysis.new(<<~MARKDOWN)
          # Common Heading

          Dest unique paragraph.

          ## Dest Only Section

          Dest section content.
        MARKDOWN
      end

      it "sorts alignment with match, template_only, and dest_only entries" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align

        expect(alignment).to be_an(Array)
        types = alignment.map { |e| e[:type] }

        # Should have matches (common heading) and various only types
        expect(types).to include(:match)
      end
    end

    context "with empty template" do
      let(:template_analysis) { Markly::Merge::FileAnalysis.new("") }
      let(:dest_analysis) do
        Markly::Merge::FileAnalysis.new("# Dest\n\nContent.\n")
      end

      it "produces only dest_only entries" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align

        expect(alignment).to be_an(Array)
        # All entries should be dest_only - covers sort branch
        alignment.each do |entry|
          expect(entry[:type]).to eq(:dest_only)
        end
      end
    end

    context "with empty dest" do
      let(:template_analysis) do
        Markly::Merge::FileAnalysis.new("# Template\n\nContent.\n")
      end
      let(:dest_analysis) { Markly::Merge::FileAnalysis.new("") }

      it "produces only template_only entries" do
        aligner = described_class.new(template_analysis, dest_analysis)
        alignment = aligner.align

        expect(alignment).to be_an(Array)
        # All entries should be template_only - covers sort branch
        alignment.each do |entry|
          expect(entry[:type]).to eq(:template_only)
        end
      end
    end
  end
end
