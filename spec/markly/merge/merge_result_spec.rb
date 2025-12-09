# frozen_string_literal: true

RSpec.describe Markly::Merge::MergeResult do
  describe "#initialize" do
    it "creates a result with content" do
      result = described_class.new(content: "# Title")
      expect(result.content).to eq("# Title")
    end

    it "defaults conflicts to empty array" do
      result = described_class.new(content: "content")
      expect(result.conflicts).to eq([])
    end

    it "defaults frozen_blocks to empty array" do
      result = described_class.new(content: "content")
      expect(result.frozen_blocks).to eq([])
    end

    it "defaults stats with zeros" do
      result = described_class.new(content: "content")
      expect(result.stats[:nodes_added]).to eq(0)
      expect(result.stats[:nodes_removed]).to eq(0)
      expect(result.stats[:nodes_modified]).to eq(0)
      expect(result.stats[:merge_time_ms]).to eq(0)
    end

    it "accepts custom conflicts" do
      conflicts = [{location: "line 5", description: "conflict"}]
      result = described_class.new(content: "content", conflicts: conflicts)
      expect(result.conflicts).to eq(conflicts)
    end

    it "accepts custom frozen_blocks" do
      blocks = [{start_line: 5, end_line: 10}]
      result = described_class.new(content: "content", frozen_blocks: blocks)
      expect(result.frozen_blocks).to eq(blocks)
    end

    it "merges custom stats with defaults" do
      result = described_class.new(content: "content", stats: {nodes_added: 5})
      expect(result.stats[:nodes_added]).to eq(5)
      expect(result.stats[:nodes_removed]).to eq(0)
    end
  end

  describe "#success?" do
    it "returns true when no conflicts and has content" do
      result = described_class.new(content: "content", conflicts: [])
      expect(result.success?).to be true
    end

    it "returns false when conflicts present" do
      result = described_class.new(content: "content", conflicts: [{location: "line 1"}])
      expect(result.success?).to be false
    end

    it "returns false when content is nil" do
      result = described_class.new(content: nil, conflicts: [])
      expect(result.success?).to be false
    end
  end

  describe "#conflicts?" do
    it "returns true when conflicts present" do
      result = described_class.new(content: "content", conflicts: [{location: "line 1"}])
      expect(result.conflicts?).to be true
    end

    it "returns false when no conflicts" do
      result = described_class.new(content: "content", conflicts: [])
      expect(result.conflicts?).to be false
    end
  end

  describe "#has_frozen_blocks?" do
    it "returns true when frozen blocks present" do
      result = described_class.new(
        content: "content",
        frozen_blocks: [{start_line: 5, end_line: 10}],
      )
      expect(result.has_frozen_blocks?).to be true
    end

    it "returns false when no frozen blocks" do
      result = described_class.new(content: "content", frozen_blocks: [])
      expect(result.has_frozen_blocks?).to be false
    end
  end

  describe "#nodes_added" do
    it "returns nodes_added from stats" do
      result = described_class.new(content: "content", stats: {nodes_added: 3})
      expect(result.nodes_added).to eq(3)
    end

    it "returns 0 when not set" do
      result = described_class.new(content: "content", stats: {})
      expect(result.nodes_added).to eq(0)
    end
  end

  describe "#nodes_removed" do
    it "returns nodes_removed from stats" do
      result = described_class.new(content: "content", stats: {nodes_removed: 2})
      expect(result.nodes_removed).to eq(2)
    end

    it "returns 0 when not set" do
      result = described_class.new(content: "content", stats: {})
      expect(result.nodes_removed).to eq(0)
    end
  end

  describe "#nodes_modified" do
    it "returns nodes_modified from stats" do
      result = described_class.new(content: "content", stats: {nodes_modified: 4})
      expect(result.nodes_modified).to eq(4)
    end

    it "returns 0 when not set" do
      result = described_class.new(content: "content", stats: {})
      expect(result.nodes_modified).to eq(0)
    end
  end

  describe "#frozen_count" do
    it "returns count of frozen blocks" do
      result = described_class.new(
        content: "content",
        frozen_blocks: [
          {start_line: 1, end_line: 5},
          {start_line: 10, end_line: 15},
        ],
      )
      expect(result.frozen_count).to eq(2)
    end

    it "returns 0 when no frozen blocks" do
      result = described_class.new(content: "content")
      expect(result.frozen_count).to eq(0)
    end
  end

  describe "#content_string" do
    it "returns the content as a string" do
      result = described_class.new(content: "# Title\n\nParagraph.")
      expect(result.content_string).to eq("# Title\n\nParagraph.")
    end

    it "returns nil when content is nil" do
      result = described_class.new(content: nil)
      expect(result.content_string).to be_nil
    end
  end

  describe "#inspect" do
    it "shows success status" do
      result = described_class.new(content: "content")
      expect(result.inspect).to include("success")
    end

    it "shows failed status when conflicts" do
      result = described_class.new(content: "content", conflicts: [{loc: 1}])
      expect(result.inspect).to include("failed")
    end

    it "shows conflict count" do
      result = described_class.new(content: "content", conflicts: [{loc: 1}, {loc: 2}])
      expect(result.inspect).to include("conflicts=2")
    end

    it "shows frozen count" do
      result = described_class.new(content: "content", frozen_blocks: [{start: 1}])
      expect(result.inspect).to include("frozen=1")
    end
  end

  describe "inheritance" do
    it "inherits from Ast::Merge::MergeResultBase" do
      expect(described_class.superclass).to eq(Ast::Merge::MergeResultBase)
    end
  end
end
