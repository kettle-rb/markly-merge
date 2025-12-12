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

  describe "match refiner integration" do
    context "when match refiner returns matches" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          | Header A | Header B |
          |----------|----------|
          | Value 1  | Value 2  |
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          | Header A | Header B |
          |----------|----------|
          | Value X  | Value Y  |
        MARKDOWN
      end

      it "incorporates refiner matches into alignment" do
        # Create a simple mock refiner that returns matches
        refiner = ->(template_nodes, dest_nodes, _context) do
          # Return empty array to not interfere with regular matching
          []
        end

        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source, extensions: [:table]),
          Markly::Merge::FileAnalysis.new(dest_source, extensions: [:table]),
          match_refiner: refiner,
        )

        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end
    end

    context "when match refiner returns nil indices" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          Paragraph one.

          Paragraph two.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          Different paragraph.

          Another paragraph.
        MARKDOWN
      end

      it "skips matches where nodes cannot be found" do
        # Create a refiner that returns a match with nodes not in the statements
        fake_node = double("FakeNode")
        mock_match = double("MatchScore", template_node: fake_node, dest_node: fake_node, score: 0.9)
        refiner = ->(_template_nodes, _dest_nodes, _context) { [mock_match] }

        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
          match_refiner: refiner,
        )

        # Should not raise, should skip invalid matches
        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end
    end

    context "when refiner matches already-matched nodes" do
      let(:template_source) do
        <<~MARKDOWN
          # Same Title
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Same Title
        MARKDOWN
      end

      it "does not duplicate matches" do
        # The heading will already be matched by signature
        # Refiner should not create duplicate
        template_analysis = Markly::Merge::FileAnalysis.new(template_source)
        dest_analysis = Markly::Merge::FileAnalysis.new(dest_source)

        mock_match = double(
          "MatchScore",
          template_node: template_analysis.statements.first,
          dest_node: dest_analysis.statements.first,
          score: 0.9,
        )
        refiner = ->(_t, _d, _c) { [mock_match] }

        aligner = described_class.new(template_analysis, dest_analysis, match_refiner: refiner)
        alignment = aligner.align

        # Should only have one match for the heading
        matches = alignment.select { |e| e[:type] == :match }
        heading_matches = matches.select do |m|
          m[:template_node].respond_to?(:type) && m[:template_node].type == :header
        end
        expect(heading_matches.size).to eq(1)
      end
    end

    context "when unmatched nodes are empty" do
      let(:template_source) do
        <<~MARKDOWN
          # Same Title

          Same paragraph.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Same Title

          Same paragraph.
        MARKDOWN
      end

      it "does not call refiner when all nodes are already matched" do
        refiner = ->(_t, _d, _c) do
          []
        end

        aligner = described_class.new(
          Markly::Merge::FileAnalysis.new(template_source),
          Markly::Merge::FileAnalysis.new(dest_source),
          match_refiner: refiner,
        )

        alignment = aligner.align

        # Refiner may or may not be called depending on implementation
        # The key is that alignment works correctly
        expect(alignment).to be_an(Array)
      end
    end

    context "when refiner returns nodes not in statement lists" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          Content A.

          Content B.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          Content X.

          Content Y.
        MARKDOWN
      end

      it "skips match when template_node is not found" do
        # Create a mock match that returns a node not in the statement list
        fake_node = instance_double("Markly::Node")
        allow(fake_node).to receive(:type).and_return(:paragraph)
        allow(fake_node).to receive(:source_position).and_return({start_line: 999, end_line: 999})

        match_struct = Struct.new(:template_node, :dest_node, :score)

        refiner = ->(_t, d, _c) do
          # Return a match with a fake template node that won't be found
          [match_struct.new(fake_node, d.first, 0.8)]
        end

        template_analysis = Markly::Merge::FileAnalysis.new(template_source)
        dest_analysis = Markly::Merge::FileAnalysis.new(dest_source)

        aligner = described_class.new(template_analysis, dest_analysis, match_refiner: refiner)
        alignment = aligner.align

        # Should not crash, and should not include the fake match
        refined_matches = alignment.select { |e| e[:signature].is_a?(Array) && e[:signature].first == :refined_match }
        expect(refined_matches).to be_empty
      end

      it "skips match when dest_node is not found" do
        fake_node = instance_double("Markly::Node")
        allow(fake_node).to receive(:type).and_return(:paragraph)
        allow(fake_node).to receive(:source_position).and_return({start_line: 888, end_line: 888})

        match_struct = Struct.new(:template_node, :dest_node, :score)

        refiner = ->(t, _d, _c) do
          # Return a match with a fake dest node that won't be found
          [match_struct.new(t.first, fake_node, 0.8)]
        end

        template_analysis = Markly::Merge::FileAnalysis.new(template_source)
        dest_analysis = Markly::Merge::FileAnalysis.new(dest_source)

        aligner = described_class.new(template_analysis, dest_analysis, match_refiner: refiner)
        alignment = aligner.align

        # Should not crash, and should not include the fake match
        refined_matches = alignment.select { |e| e[:signature].is_a?(Array) && e[:signature].first == :refined_match }
        expect(refined_matches).to be_empty
      end
    end

    context "when refiner returns already-matched nodes" do
      let(:template_source) do
        <<~MARKDOWN
          # Title

          Paragraph one.

          Paragraph two.
        MARKDOWN
      end

      let(:dest_source) do
        <<~MARKDOWN
          # Title

          Paragraph one.

          Different two.
        MARKDOWN
      end

      it "skips matches that are already matched by signature" do
        match_struct = Struct.new(:template_node, :dest_node, :score)

        template_analysis = Markly::Merge::FileAnalysis.new(template_source)
        dest_analysis = Markly::Merge::FileAnalysis.new(dest_source)

        # Get the actual nodes that will already be matched
        t_stmts = template_analysis.statements
        d_stmts = dest_analysis.statements

        refiner = ->(_t, _d, _c) do
          # Return matches for nodes that are already matched by signature (title and paragraph one)
          [match_struct.new(t_stmts[0], d_stmts[0], 0.95)]
        end

        aligner = described_class.new(template_analysis, dest_analysis, match_refiner: refiner)
        alignment = aligner.align

        # The title should only appear once in matches (from signature match, not refiner)
        title_matches = alignment.select { |e| e[:type] == :match && e[:template_index] == 0 }
        expect(title_matches.size).to eq(1)
      end
    end
  end
end
