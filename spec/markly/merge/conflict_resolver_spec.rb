# frozen_string_literal: true

require "ast/merge/rspec/shared_examples"

RSpec.describe Markly::Merge::ConflictResolver do
  # Use shared examples to validate base ConflictResolverBase integration
  it_behaves_like "Ast::Merge::ConflictResolverBase" do
    let(:conflict_resolver_class) { described_class }
    let(:strategy) { :node }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      }
    end
    let(:build_mock_analysis) do
      -> {
        source = "# Mock Content\n"
        Markly::Merge::FileAnalysis.new(source)
      }
    end
  end

  it_behaves_like "Ast::Merge::ConflictResolverBase node strategy" do
    let(:conflict_resolver_class) { described_class }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      }
    end
    let(:build_mock_analysis) do
      -> {
        source = "# Mock Content\n"
        Markly::Merge::FileAnalysis.new(source)
      }
    end
  end

  let(:template_source) do
    <<~MARKDOWN
      # Title

      Template content.
    MARKDOWN
  end

  let(:dest_source) do
    <<~MARKDOWN
      # Title

      Destination content.
    MARKDOWN
  end

  let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_source) }
  let(:dest_analysis) { Markly::Merge::FileAnalysis.new(dest_source) }

  describe "#initialize" do
    it "creates a resolver with preference" do
      resolver = described_class.new(
        preference: :destination,
        template_analysis: template_analysis,
        dest_analysis: dest_analysis,
      )
      expect(resolver.preference).to eq(:destination)
    end

    it "stores analyses" do
      resolver = described_class.new(
        preference: :destination,
        template_analysis: template_analysis,
        dest_analysis: dest_analysis,
      )
      expect(resolver.template_analysis).to eq(template_analysis)
      expect(resolver.dest_analysis).to eq(dest_analysis)
    end
  end

  describe "#resolve" do
    # Use the paragraph (index 1) which has different content
    let(:template_node) { template_analysis.statements[1] }
    let(:dest_node) { dest_analysis.statements[1] }

    context "with :destination preference" do
      let(:resolver) do
        described_class.new(
          preference: :destination,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      end

      it "returns destination source" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:source]).to eq(:destination)
      end

      it "returns DECISION_DESTINATION" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:decision]).to eq(described_class::DECISION_DESTINATION)
      end

      it "includes both nodes" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:template_node]).to eq(template_node)
        expect(resolution[:dest_node]).to eq(dest_node)
      end
    end

    context "with :template preference" do
      let(:resolver) do
        described_class.new(
          preference: :template,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      end

      it "returns template source" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:source]).to eq(:template)
      end

      it "returns DECISION_TEMPLATE" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:decision]).to eq(described_class::DECISION_TEMPLATE)
      end
    end

    context "with identical content" do
      let(:identical_source) { "# Same Title" }
      let(:template_analysis) { Markly::Merge::FileAnalysis.new(identical_source) }
      let(:dest_analysis) { Markly::Merge::FileAnalysis.new(identical_source) }
      let(:template_node) { template_analysis.statements.first }
      let(:dest_node) { dest_analysis.statements.first }

      let(:resolver) do
        described_class.new(
          preference: :destination,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      end

      it "returns :identical decision" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:decision]).to eq(:identical)
      end

      it "prefers destination for identical content" do
        resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:source]).to eq(:destination)
      end
    end

    context "with frozen destination node" do
      let(:dest_source) do
        <<~MARKDOWN
          <!-- markly-merge:freeze Custom reason -->
          ## Frozen Section
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end
      let(:dest_analysis) { Markly::Merge::FileAnalysis.new(dest_source) }
      let(:freeze_node) { dest_analysis.freeze_blocks.first }

      let(:resolver) do
        described_class.new(
          preference: :template, # Even with template preference
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      end

      it "returns frozen decision" do
        expect(freeze_node).to be_a(Markly::Merge::FreezeNode)
        resolution = resolver.resolve(template_node, freeze_node, template_index: 0, dest_index: 0)
        expect(resolution[:decision]).to eq(described_class::DECISION_FROZEN)
      end

      it "uses destination source for frozen" do
        resolution = resolver.resolve(template_node, freeze_node, template_index: 0, dest_index: 0)
        expect(resolution[:source]).to eq(:destination)
      end

      it "includes reason" do
        resolution = resolver.resolve(template_node, freeze_node, template_index: 0, dest_index: 0)
        expect(resolution[:reason]).to eq("Custom reason")
      end
    end

    context "with frozen template node" do
      let(:template_source) do
        <<~MARKDOWN
          <!-- markly-merge:freeze -->
          ## Template Frozen
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end
      let(:template_analysis) { Markly::Merge::FileAnalysis.new(template_source) }
      let(:template_freeze_node) { template_analysis.freeze_blocks.first }
      let(:dest_node) { dest_analysis.statements.first }

      let(:resolver) do
        described_class.new(
          preference: :destination,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
      end

      it "returns frozen decision" do
        expect(template_freeze_node).to be_a(Markly::Merge::FreezeNode)
        resolution = resolver.resolve(template_freeze_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:decision]).to eq(described_class::DECISION_FROZEN)
      end

      it "uses template source for frozen template" do
        resolution = resolver.resolve(template_freeze_node, dest_node, template_index: 0, dest_index: 0)
        expect(resolution[:source]).to eq(:template)
      end
    end
  end

  describe "#node_to_text" do
    let(:resolver) do
      described_class.new(
        preference: :destination,
        template_analysis: template_analysis,
        dest_analysis: dest_analysis,
      )
    end

    context "with FreezeNode" do
      let(:freeze_source) do
        <<~MARKDOWN
          <!-- markly-merge:freeze -->
          Frozen content here
          <!-- markly-merge:unfreeze -->
        MARKDOWN
      end
      let(:freeze_analysis) { Markly::Merge::FileAnalysis.new(freeze_source) }
      let(:freeze_node) { freeze_analysis.freeze_blocks.first }

      it "returns full_text for FreezeNode" do
        expect(freeze_node).to be_a(Markly::Merge::FreezeNode)
        result = resolver.send(:node_to_text, freeze_node, freeze_analysis)
        expect(result).to be_a(String)
        expect(result).to include("Frozen content")
      end
    end

    context "with node without source_position" do
      it "falls back to to_commonmark" do
        node = double("MockNode")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive(:source_position).and_return(nil)
        allow(node).to receive(:to_commonmark).and_return("commonmark output")

        result = resolver.send(:node_to_text, node, template_analysis)
        expect(result).to eq("commonmark output")
      end
    end

    context "with node with incomplete position (missing end line)" do
      it "falls back to to_commonmark" do
        node = double("MockNode")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive(:source_position).and_return({start_line: 1})
        allow(node).to receive(:to_commonmark).and_return("fallback output")

        result = resolver.send(:node_to_text, node, template_analysis)
        expect(result).to eq("fallback output")
      end
    end

    context "with node with complete position" do
      let(:node) { template_analysis.statements.first }

      it "returns source_range from analysis" do
        result = resolver.send(:node_to_text, node, template_analysis)
        expect(result).to be_a(String)
        expect(result).to include("Title")
      end

      it "uses source_range when position info is present" do
        # Verify the node has position info
        pos = node.source_position
        expect(pos).not_to be_nil

        # This should use the source_range path (the then branch)
        result = resolver.send(:node_to_text, node, template_analysis)
        expect(result).to be_a(String)
        expect(result.length).to be > 0
      end
    end
  end
end
