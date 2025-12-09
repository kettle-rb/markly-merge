# frozen_string_literal: true

RSpec.describe Markly::Merge::TableMatchRefiner do
  subject(:refiner) { described_class.new(**options) }

  let(:options) { {} }

  describe "#initialize" do
    it "uses default threshold of 0.5" do
      expect(refiner.threshold).to eq(0.5)
    end

    it "accepts algorithm_options" do
      refiner_with_opts = described_class.new(algorithm_options: {weights: {header_match: 0.5}})
      expect(refiner_with_opts.algorithm_options).to eq({weights: {header_match: 0.5}})
    end

    context "with custom options" do
      let(:options) { {threshold: 0.6} }

      it "uses custom threshold" do
        expect(refiner.threshold).to eq(0.6)
      end
    end
  end

  describe "#call" do
    let(:template_md) { <<~MD }
      # Document

      | Name | Age | City |
      |------|-----|------|
      | Alice | 30 | NYC |
      | Bob | 25 | LA |

      Some text here.

      | Product | Price | Stock |
      |---------|-------|-------|
      | Widget | $10 | 100 |
      | Gadget | $20 | 50 |
    MD

    let(:dest_md) { <<~MD }
      # Document

      | Name | Age | Location |
      |------|-----|----------|
      | Alice | 30 | Boston |
      | Charlie | 35 | Chicago |

      Some other text.

      | Item | Cost | Quantity |
      |------|------|----------|
      | Widget | $15 | 80 |
    MD

    let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_md) }
    let(:dest_analysis) { Markly::Merge::FileAnalysis.new(dest_md) }

    let(:template_tables) do
      template_analysis.statements.select { |n| n.respond_to?(:type) && n.type == :table }
    end

    let(:dest_tables) do
      dest_analysis.statements.select { |n| n.respond_to?(:type) && n.type == :table }
    end

    it "matches tables with similar headers" do
      matches = refiner.call(template_tables, dest_tables)

      # First table (Name/Age) should match first dest table (Name/Age)
      expect(matches).not_to be_empty
    end

    it "returns MatchResult objects with scores" do
      matches = refiner.call(template_tables, dest_tables)

      expect(matches).to all(be_a(Ast::Merge::MatchRefinerBase::MatchResult))
      expect(matches.map(&:score)).to all(be_a(Float))
      expect(matches.map(&:score)).to all(be >= refiner.threshold)
    end

    context "with high threshold" do
      let(:options) { {threshold: 0.95} }

      it "returns fewer matches" do
        matches = refiner.call(template_tables, dest_tables)

        # With very high threshold, only nearly identical tables should match
        expect(matches.size).to be <= 1
      end
    end

    context "when one list is empty" do
      it "returns empty array for empty template" do
        matches = refiner.call([], dest_tables)
        expect(matches).to eq([])
      end

      it "returns empty array for empty destination" do
        matches = refiner.call(template_tables, [])
        expect(matches).to eq([])
      end
    end

    context "with identical tables" do
      let(:dest_md) { <<~MD }
        # Document

        | Name | Age | City |
        |------|-----|------|
        | Alice | 30 | NYC |
        | Bob | 25 | LA |
      MD

      it "matches identical tables with high score" do
        matches = refiner.call(template_tables, dest_tables)

        expect(matches).not_to be_empty
        expect(matches.first.score).to be >= 0.8
      end
    end
  end

  describe "greedy matching" do
    let(:template_md) { <<~MD }
      | A | B |
      |---|---|
      | 1 | 2 |

      | C | D |
      |---|---|
      | 3 | 4 |

      | E | F |
      |---|---|
      | 5 | 6 |
    MD

    let(:dest_md) { <<~MD }
      | AA | BB |
      |----|-----|
      | 1 | 2 |

      | CC | DD |
      |----|-----|
      | 3 | 4 |
    MD

    let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_md) }
    let(:dest_analysis) { Markly::Merge::FileAnalysis.new(dest_md) }

    let(:template_tables) do
      template_analysis.statements.select { |n| n.respond_to?(:type) && n.type == :table }
    end

    let(:dest_tables) do
      dest_analysis.statements.select { |n| n.respond_to?(:type) && n.type == :table }
    end

    it "ensures each destination table is matched at most once" do
      matches = refiner.call(template_tables, dest_tables)

      dest_nodes = matches.map(&:dest_node)
      expect(dest_nodes.uniq.size).to eq(dest_nodes.size)
    end

    it "ensures each template table is matched at most once" do
      matches = refiner.call(template_tables, dest_tables)

      template_nodes = matches.map(&:template_node)
      expect(template_nodes.uniq.size).to eq(template_nodes.size)
    end
  end

  describe "#table_node?" do
    let(:template_md) { <<~MD }
      # Heading

      | A | B |
      |---|---|
      | 1 | 2 |

      Paragraph text.
    MD

    let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_md) }

    it "identifies table nodes correctly" do
      table_nodes = template_analysis.statements.select { |n| n.respond_to?(:type) && n.type == :table }
      non_table_nodes = template_analysis.statements.reject { |n| n.respond_to?(:type) && n.type == :table }

      table_nodes.each do |node|
        expect(refiner.send(:table_node?, node)).to be true
      end

      non_table_nodes.each do |node|
        expect(refiner.send(:table_node?, node)).to be false
      end
    end

    context "with node that has Table in class name" do
      it "identifies as table by class name" do
        # Create a mock object with "Table" in its class name
        table_like = Class.new do
          def self.name
            "CustomTableNode"
          end
        end.new

        expect(refiner.send(:table_node?, table_like)).to be true
      end
    end

    context "with node that doesn't respond to type" do
      it "returns false for non-table objects" do
        plain_object = Object.new
        expect(refiner.send(:table_node?, plain_object)).to be false
      end
    end
  end
end
