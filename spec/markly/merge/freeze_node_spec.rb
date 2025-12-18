# frozen_string_literal: true

require "ast/merge/rspec/shared_examples"

RSpec.describe Markly::Merge::FreezeNode do
  # Note: We include only specific shared examples rather than the full "Ast::Merge::FreezeNodeBase"
  # shared example group, because Markly::Merge::FreezeNode has a custom signature format
  # (:freeze_block instead of :FreezeNodeBase) that is intentionally different from the base class.
  # The shared examples below test the contract that IS shared.

  let(:freeze_node_class) { described_class }
  let(:default_pattern_type) { :html_comment }
  let(:build_freeze_node) do
    ->(start_line:, end_line:, **opts) {
      content = opts.delete(:content) || "## Frozen Section\n\nFrozen content line #{start_line} to #{end_line}."
      # Note: Markly::Merge::FreezeNode hard-codes pattern_type to :html_comment internally
      # so we don't pass it to the constructor
      freeze_node_class.new(
        start_line: start_line,
        end_line: end_line,
        content: content,
        start_marker: opts[:start_marker] || "<!-- markly-merge:freeze -->",
        end_marker: opts[:end_marker] || "<!-- markly-merge:unfreeze -->",
        nodes: opts[:nodes] || [],
        reason: opts[:reason],
      )
    }
  end

  # Shared contract tests (subset that applies to markly's implementation)
  describe "instance methods (shared contract)" do
    let(:freeze_node) { build_freeze_node.call(start_line: 5, end_line: 10) }

    describe "#start_line" do
      it "returns the start line number" do
        expect(freeze_node.start_line).to eq(5)
      end
    end

    describe "#end_line" do
      it "returns the end line number" do
        expect(freeze_node.end_line).to eq(10)
      end
    end

    describe "#location" do
      it "returns a location object" do
        expect(freeze_node.location).to respond_to(:start_line)
        expect(freeze_node.location).to respond_to(:end_line)
      end

      it "has correct line numbers" do
        expect(freeze_node.location.start_line).to eq(5)
        expect(freeze_node.location.end_line).to eq(10)
      end
    end

    describe "#freeze_node?" do
      it "returns true" do
        expect(freeze_node.freeze_node?).to be true
      end
    end

    describe "#signature" do
      it "returns an Array" do
        expect(freeze_node.signature).to be_an(Array)
      end

      # Markly uses :freeze_block (not :FreezeNodeBase) as a content-based signature
      it "starts with :freeze_block" do
        expect(freeze_node.signature.first).to eq(:freeze_block)
      end
    end

    describe "#inspect" do
      it "returns a string representation" do
        expect(freeze_node.inspect).to be_a(String)
        expect(freeze_node.inspect).to include("5")
        expect(freeze_node.inspect).to include("10")
      end
    end
  end

  # Markly-specific tests
  describe ".pattern_for" do
    context "without token (returns Hash)" do
      it "returns a hash with :start and :end keys" do
        pattern = described_class.pattern_for(:html_comment)
        expect(pattern).to be_a(Hash)
        expect(pattern).to have_key(:start)
        expect(pattern).to have_key(:end)
      end

      it "has working start pattern" do
        pattern = described_class.pattern_for(:html_comment)
        expect("<!-- markly-merge:freeze -->").to match(pattern[:start])
      end

      it "has working end pattern" do
        pattern = described_class.pattern_for(:html_comment)
        expect("<!-- markly-merge:unfreeze -->").to match(pattern[:end])
      end
    end

    context "with token (returns Regexp)" do
      it "builds html_comment pattern with default token" do
        pattern = described_class.pattern_for(:html_comment, "markly-merge")
        expect(pattern).to be_a(Regexp)
        expect("<!-- markly-merge:freeze -->").to match(pattern)
        expect("<!-- markly-merge:unfreeze -->").to match(pattern)
      end

      it "builds html_comment pattern with custom token" do
        pattern = described_class.pattern_for(:html_comment, "my-token")
        expect("<!-- my-token:freeze -->").to match(pattern)
        expect("<!-- my-token:unfreeze -->").to match(pattern)
        expect("<!-- markly-merge:freeze -->").not_to match(pattern)
      end

      it "escapes regex special characters in token" do
        pattern = described_class.pattern_for(:html_comment, "my.token")
        expect("<!-- my.token:freeze -->").to match(pattern)
        expect("<!-- myXtoken:freeze -->").not_to match(pattern)
      end

      it "captures marker type" do
        pattern = described_class.pattern_for(:html_comment, "markly-merge")
        match = "<!-- markly-merge:freeze -->".match(pattern)
        expect(match[1]).to eq("freeze")

        match = "<!-- markly-merge:unfreeze -->".match(pattern)
        expect(match[1]).to eq("unfreeze")
      end

      it "captures optional reason" do
        pattern = described_class.pattern_for(:html_comment, "markly-merge")
        match = "<!-- markly-merge:freeze My Reason -->".match(pattern)
        expect(match[2]).to eq("My Reason")
      end

      it "handles no reason" do
        pattern = described_class.pattern_for(:html_comment, "markly-merge")
        match = "<!-- markly-merge:freeze -->".match(pattern)
        expect(match[2]).to be_nil
      end
    end

    it "delegates unknown patterns to parent" do
      expect { described_class.pattern_for(:unknown_type) }.to raise_error(ArgumentError)
    end
  end

  describe "#initialize" do
    let(:freeze_node) do
      described_class.new(
        start_line: 5,
        end_line: 10,
        content: "## Frozen Section\n\nFrozen content.",
        start_marker: "<!-- markly-merge:freeze -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
        nodes: [],
      )
    end

    it "stores start_line" do
      expect(freeze_node.start_line).to eq(5)
    end

    it "stores end_line" do
      expect(freeze_node.end_line).to eq(10)
    end

    it "stores content" do
      expect(freeze_node.content).to eq("## Frozen Section\n\nFrozen content.")
    end

    it "stores start_marker" do
      expect(freeze_node.start_marker).to eq("<!-- markly-merge:freeze -->")
    end

    it "stores end_marker" do
      expect(freeze_node.end_marker).to eq("<!-- markly-merge:unfreeze -->")
    end

    it "stores nodes" do
      expect(freeze_node.nodes).to eq([])
    end

    context "with explicit reason" do
      let(:freeze_node) do
        described_class.new(
          start_line: 1,
          end_line: 3,
          content: "content",
          start_marker: "<!-- markly-merge:freeze -->",
          end_marker: "<!-- markly-merge:unfreeze -->",
          reason: "Explicit reason",
        )
      end

      it "uses explicit reason" do
        expect(freeze_node.reason).to eq("Explicit reason")
      end
    end

    context "with reason in marker" do
      let(:freeze_node) do
        described_class.new(
          start_line: 1,
          end_line: 3,
          content: "content",
          start_marker: "<!-- markly-merge:freeze Custom Reason -->",
          end_marker: "<!-- markly-merge:unfreeze -->",
        )
      end

      it "extracts reason from marker" do
        expect(freeze_node.reason).to eq("Custom Reason")
      end
    end

    context "without reason" do
      let(:freeze_node) do
        described_class.new(
          start_line: 1,
          end_line: 3,
          content: "content",
          start_marker: "<!-- markly-merge:freeze -->",
          end_marker: "<!-- markly-merge:unfreeze -->",
        )
      end

      it "has nil reason" do
        expect(freeze_node.reason).to be_nil
      end
    end
  end

  describe "#signature" do
    let(:freeze_node) do
      described_class.new(
        start_line: 1,
        end_line: 3,
        content: "## Test Content",
        start_marker: "<!-- markly-merge:freeze -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
    end

    it "returns array with :freeze_block" do
      sig = freeze_node.signature
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:freeze_block)
    end

    it "includes content hash" do
      sig = freeze_node.signature
      expect(sig.size).to eq(2)
      expect(sig.last).to be_a(String)
      expect(sig.last.length).to eq(16)
    end

    it "produces same signature for same content" do
      node1 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Same content",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
      )
      node2 = described_class.new(
        start_line: 10,
        end_line: 20,
        content: "Same content",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
      )
      expect(node1.signature).to eq(node2.signature)
    end

    it "produces different signature for different content" do
      node1 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Content A",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
      )
      node2 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Content B",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
      )
      expect(node1.signature).not_to eq(node2.signature)
    end
  end

  describe "#full_text" do
    let(:freeze_node) do
      described_class.new(
        start_line: 1,
        end_line: 5,
        content: "## Section\n\nContent",
        start_marker: "<!-- markly-merge:freeze -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
    end

    it "returns complete block with markers" do
      expected = <<~TEXT.chomp
        <!-- markly-merge:freeze -->
        ## Section

        Content
        <!-- markly-merge:unfreeze -->
      TEXT
      expect(freeze_node.full_text).to eq(expected)
    end
  end

  describe "#line_count" do
    it "returns correct count" do
      node = described_class.new(
        start_line: 5,
        end_line: 10,
        content: "",
        start_marker: "",
        end_marker: "",
      )
      expect(node.line_count).to eq(6)
    end

    it "handles single line" do
      node = described_class.new(
        start_line: 5,
        end_line: 5,
        content: "",
        start_marker: "",
        end_marker: "",
      )
      expect(node.line_count).to eq(1)
    end
  end

  describe "#contains_type?" do
    let(:mock_header) { double("Node", type: :header) }
    let(:mock_paragraph) { double("Node", type: :paragraph) }

    let(:freeze_node) do
      described_class.new(
        start_line: 1,
        end_line: 5,
        content: "content",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
        nodes: [mock_header, mock_paragraph],
      )
    end

    it "returns true for contained type" do
      expect(freeze_node.contains_type?(:header)).to be true
      expect(freeze_node.contains_type?(:paragraph)).to be true
    end

    it "returns false for non-contained type" do
      expect(freeze_node.contains_type?(:code_block)).to be false
    end
  end

  describe "#inspect" do
    let(:freeze_node) do
      described_class.new(
        start_line: 5,
        end_line: 10,
        content: "content",
        start_marker: "<!-- m:freeze -->",
        end_marker: "<!-- m:unfreeze -->",
        nodes: [],
        reason: "Test reason",
      )
    end

    it "returns readable representation" do
      result = freeze_node.inspect
      expect(result).to include("FreezeNode")
      expect(result).to include("5..10")
      expect(result).to include("nodes=0")
      expect(result).to include("Test reason")
    end
  end

  describe "inheritance" do
    it "inherits from Markdown::Merge::FreezeNode" do
      expect(described_class.superclass).to eq(Markdown::Merge::FreezeNode)
    end
  end

  describe ".pattern_for edge cases" do
    it "returns pattern hash when no token provided" do
      pattern = described_class.pattern_for(:html_comment)
      expect(pattern).to be_a(Hash)
      expect(pattern[:start]).to be_a(Regexp)
      expect(pattern[:end]).to be_a(Regexp)
    end

    it "builds pattern with custom token" do
      pattern = described_class.pattern_for(:html_comment, "custom-token")
      expect(pattern).to be_a(Regexp)
      expect("<!-- custom-token:freeze -->").to match(pattern)
    end
  end

  describe "#reason extraction via base class pattern_for" do
    it "extracts reason when present" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze Custom Reason Here -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      expect(node.reason).to eq("Custom Reason Here")
    end

    it "returns nil for marker without reason" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      expect(node.reason).to be_nil
    end

    it "returns nil for nil marker" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: nil,
        end_marker: nil,
      )
      expect(node.reason).to be_nil
    end

    it "returns nil for marker without reason text" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      expect(node.reason).to be_nil
    end

    it "handles reason with special characters" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze Keep this: important! -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      expect(node.reason).to eq("Keep this: important!")
    end

    it "returns nil for marker that does not match freeze pattern" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- some other comment -->",
        end_marker: "<!-- end -->",
      )
      expect(node.reason).to be_nil
    end

    it "extracts reason even when it starts with dash (base class behavior)" do
      # Base class pattern_for captures all text after freeze directive
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze -invalid -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      # Base class doesn't filter out dash-prefixed reasons
      expect(node.reason).to eq("-invalid")
    end

    it "returns nil for empty reason after strip" do
      node = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "content",
        start_marker: "<!-- markly-merge:freeze    -->",
        end_marker: "<!-- markly-merge:unfreeze -->",
      )
      expect(node.reason).to be_nil
    end
  end

  describe ".pattern_for with non-html_comment type" do
    it "delegates to base class for other pattern types with token" do
      # This tests the else branch that calls super
      # The base class handles hash_comment pattern
      pattern = described_class.pattern_for(:hash_comment, "test-token")
      expect(pattern).to be_a(Regexp)
      expect("# test-token:freeze").to match(pattern)
    end

    it "delegates to base class for other pattern types without token" do
      # Without token, returns pattern hash from base
      pattern = described_class.pattern_for(:hash_comment)
      expect(pattern).to be_a(Hash)
    end
  end
end
