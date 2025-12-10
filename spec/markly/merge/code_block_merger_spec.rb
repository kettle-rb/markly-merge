# frozen_string_literal: true

RSpec.describe Markly::Merge::CodeBlockMerger do
  describe "#initialize" do
    it "creates a merger with default settings" do
      merger = described_class.new
      expect(merger.enabled).to be true
      expect(merger.mergers).to include("ruby", "yaml", "json", "toml")
    end

    it "allows disabling inner-merge" do
      merger = described_class.new(enabled: false)
      expect(merger.enabled).to be false
    end

    it "allows custom mergers" do
      custom_merger = ->(t, d, p, **opts) { {merged: true, content: "custom"} }
      merger = described_class.new(mergers: {"custom" => custom_merger})
      expect(merger.mergers).to include("custom")
    end
  end

  describe "#supports_language?" do
    subject(:merger) { described_class.new }

    it "returns true for supported languages" do
      expect(merger.supports_language?("ruby")).to be true
      expect(merger.supports_language?("rb")).to be true
      expect(merger.supports_language?("yaml")).to be true
      expect(merger.supports_language?("yml")).to be true
      expect(merger.supports_language?("json")).to be true
      expect(merger.supports_language?("toml")).to be true
    end

    it "returns false for unsupported languages" do
      expect(merger.supports_language?("python")).to be false
      expect(merger.supports_language?("javascript")).to be false
    end

    it "is case insensitive" do
      expect(merger.supports_language?("RUBY")).to be true
      expect(merger.supports_language?("Ruby")).to be true
    end

    it "returns false when disabled" do
      disabled_merger = described_class.new(enabled: false)
      expect(disabled_merger.supports_language?("ruby")).to be false
    end

    it "returns false for nil or empty language" do
      expect(merger.supports_language?(nil)).to be false
      expect(merger.supports_language?("")).to be false
    end
  end

  describe "#merge_code_blocks" do
    subject(:merger) { described_class.new }

    let(:template_node) do
      doc = Markly.parse("```ruby\nputs 'hello'\n```")
      doc.first
    end

    let(:dest_node) do
      doc = Markly.parse("```ruby\nputs 'world'\n```")
      doc.first
    end

    context "when disabled" do
      subject(:merger) { described_class.new(enabled: false) }

      it "returns not merged" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be false
        expect(result[:reason]).to eq("inner-merge disabled")
      end
    end

    context "when no language specified" do
      let(:template_node) do
        doc = Markly.parse("```\nputs 'hello'\n```")
        doc.first
      end

      let(:dest_node) do
        doc = Markly.parse("```\nputs 'world'\n```")
        doc.first
      end

      it "returns not merged" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be false
        expect(result[:reason]).to eq("no language specified")
      end
    end

    context "when language not supported" do
      let(:template_node) do
        doc = Markly.parse("```python\nprint('hello')\n```")
        doc.first
      end

      let(:dest_node) do
        doc = Markly.parse("```python\nprint('world')\n```")
        doc.first
      end

      it "returns not merged" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be false
        expect(result[:reason]).to eq("no merger for language: python")
      end
    end

    context "when content is identical" do
      let(:dest_node) do
        doc = Markly.parse("```ruby\nputs 'hello'\n```")
        doc.first
      end

      it "returns merged with identical decision" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be true
        expect(result[:stats][:decision]).to eq(:identical)
        expect(result[:content]).to include("puts 'hello'")
      end
    end

    context "with Ruby code blocks" do
      # Use method definitions which match by name, allowing preference to control content
      let(:template_node) do
        doc = Markly.parse("```ruby\ndef greet\n  puts 'hello'\nend\n```")
        doc.first
      end

      let(:dest_node) do
        doc = Markly.parse("```ruby\ndef greet\n  puts 'world'\nend\n```")
        doc.first
      end

      it "merges Ruby code using prism-merge" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be true
        expect(result[:content]).to start_with("```ruby")
        expect(result[:content]).to end_with("```")
      end

      context "with preference :destination" do
        it "preserves destination content" do
          result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
          expect(result[:content]).to include("puts 'world'")
        end
      end

      context "with preference :template" do
        it "uses template content" do
          result = merger.merge_code_blocks(template_node, dest_node, preference: :template)
          expect(result[:content]).to include("puts 'hello'")
        end
      end
    end

    context "with method merging" do
      let(:template_node) do
        code = <<~RUBY
          def hello
            puts 'hello'
          end

          def goodbye
            puts 'goodbye'
          end
        RUBY
        doc = Markly.parse("```ruby\n#{code}```")
        doc.first
      end

      let(:dest_node) do
        code = <<~RUBY
          def hello
            puts 'hello world'
          end
        RUBY
        doc = Markly.parse("```ruby\n#{code}```")
        doc.first
      end

      it "performs inner-merge of methods" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be true
        # With destination preference, dest's hello method wins
        expect(result[:content]).to include("hello world")
      end

      it "can add template-only methods" do
        result = merger.merge_code_blocks(
          template_node,
          dest_node,
          preference: :destination,
          add_template_only_nodes: true,
        )
        expect(result[:merged]).to be true
        # Both methods should be present
        expect(result[:content]).to include("def hello")
        expect(result[:content]).to include("def goodbye")
      end
    end

    context "with parse errors" do
      let(:template_node) do
        doc = Markly.parse("```ruby\ndef broken(\n```")
        doc.first
      end

      it "returns not merged with error message" do
        result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
        expect(result[:merged]).to be false
        expect(result[:reason]).to include("Ruby parse error")
      end
    end
  end

  describe ".merge_with_prism" do
    before { require "prism/merge" }

    # Use method definitions which match by name, allowing preference to control content
    let(:template) { "def greet\n  puts 'hello'\nend" }
    let(:dest) { "def greet\n  puts 'world'\nend" }

    it "merges Ruby code" do
      result = described_class.merge_with_prism(template, dest, :destination)
      expect(result[:merged]).to be true
      expect(result[:content]).to include("def greet")
    end

    context "with template preference" do
      it "uses template content" do
        result = described_class.merge_with_prism(template, dest, :template)
        expect(result[:content]).to include("hello")
      end
    end

    context "with destination preference" do
      it "uses destination content" do
        result = described_class.merge_with_prism(template, dest, :destination)
        expect(result[:content]).to include("world")
      end
    end
  end
end
