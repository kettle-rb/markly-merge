# frozen_string_literal: true

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
        # All sections should match
        expect(matches.size).to eq(3)
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
        # Different content = different signatures = no match
        types = alignment.map { |e| e[:type] }
        expect(types).not_to include(:match)
      end
    end
  end

  describe "alignment sorting edge cases" do
    context "with mixed entry types" do
      let(:template_source) do
        <<~MARKDOWN
          # Shared Heading

          ## Template Only

          Template only content.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Shared Heading

          ## Dest Only

          Dest only content.
        MARKDOWN
      end

      it "sorts matches and dest_only before template_only" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align

        # Find indices of different types
        match_indices = alignment.each_index.select { |i| alignment[i][:type] == :match }
        template_only_indices = alignment.each_index.select { |i| alignment[i][:type] == :template_only }
        dest_only_indices = alignment.each_index.select { |i| alignment[i][:type] == :dest_only }

        # Matches and dest_only should come before template_only
        if template_only_indices.any? && (match_indices.any? || dest_only_indices.any?)
          max_match_or_dest = (match_indices + dest_only_indices).max || -1
          min_template_only = template_only_indices.min || Float::INFINITY
          expect(max_match_or_dest).to be < min_template_only
        end
      end
    end
  end

  describe "build_signature_map edge cases" do
    context "with nodes that have nil signatures" do
      let(:template_source) { "# Heading\n" }
      let(:dest_source) { "# Heading\n" }

      it "skips nil signatures in map" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        # Should not raise error
        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end
    end
  end

  describe "sorting with dest_only entries" do
    context "when destination has unique content" do
      let(:template_source) do
        <<~MARKDOWN
          # Shared
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Shared

          ## Destination Unique

          Unique content.
        MARKDOWN
      end

      it "includes dest_only entries in alignment" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align

        dest_only = alignment.select { |e| e[:type] == :dest_only }
        expect(dest_only).not_to be_empty
      end

      it "sorts dest_only entries by dest_index" do
        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
        )
        alignment = aligner.align

        dest_only = alignment.select { |e| e[:type] == :dest_only }
        if dest_only.size > 1
          indices = dest_only.map { |e| e[:dest_index] }
          expect(indices).to eq(indices.sort)
        end
      end
    end
  end
end
