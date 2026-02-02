# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markly::Merge::Backend do
  let(:backend) { described_class }

  # Store original state to restore after tests
  before do
    @original_load_attempted = backend.instance_variable_get(:@load_attempted)
    @original_loaded = backend.instance_variable_get(:@loaded)
  end

  after do
    # Restore original state
    backend.instance_variable_set(:@load_attempted, @original_load_attempted)
    backend.instance_variable_set(:@loaded, @original_loaded)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    it "memoizes the result" do
      first_result = backend.available?
      second_result = backend.available?
      expect(first_result).to eq(second_result)
    end
  end

  describe "::reset!" do
    it "resets load state" do
      backend.available? # Trigger load
      backend.reset!
      expect(backend.instance_variable_get(:@load_attempted)).to be false
      expect(backend.instance_variable_get(:@loaded)).to be false
    end
  end

  describe "::capabilities", :markly_backend do
    it "returns a hash with backend info" do
      caps = backend.capabilities
      expect(caps).to be_a(Hash)
      expect(caps[:backend]).to eq(:markly)
      expect(caps[:query]).to be false
      expect(caps[:markdown_only]).to be true
      expect(caps[:gfm_extensions]).to be true
    end
  end

  describe "Language", :markly_backend do
    describe "#initialize" do
      it "creates a language with default name :markdown" do
        lang = backend::Language.new
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:markly)
      end
    end

    describe ".markdown" do
      it "creates a markdown language" do
        lang = backend::Language.markdown
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:markly)
      end
    end
  end

  describe "Parser", :markly_backend do
    describe "#initialize" do
      it "creates a parser with nil language" do
        parser = backend::Parser.new
        expect(parser.language).to be_nil
      end
    end

    describe "#parse" do
      let(:parser) { backend::Parser.new }

      context "when language is not set" do
        it "raises an error" do
          expect { parser.parse("# Hello") }.to raise_error(RuntimeError, "Language not set")
        end
      end

      context "when language is set" do
        let(:markdown_source) { "# Heading\n\nA paragraph." }

        before do
          parser.language = backend::Language.markdown
        end

        it "returns a Tree" do
          tree = parser.parse(markdown_source)
          expect(tree).to be_a(backend::Tree)
        end

        it "parses markdown document structure" do
          tree = parser.parse(markdown_source)
          root = tree.root_node
          expect(root.type).to eq("document")
        end
      end
    end
  end

  describe "Tree", :markly_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }
    let(:source) { "# Hello\n\nA paragraph." }
    let(:tree) { parser.parse(source) }

    describe "#root_node" do
      it "returns a Node" do
        expect(tree.root_node).to be_a(backend::Node)
      end

      it "returns document as root type" do
        expect(tree.root_node.type).to eq("document")
      end
    end
  end

  describe "Node", :markly_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }
    let(:source) { "# Hello World\n\nA paragraph with **bold** text." }
    let(:tree) { parser.parse(source) }
    let(:root) { tree.root_node }

    describe "#type" do
      it "returns node type as string" do
        expect(root.type).to eq("document")
      end
    end

    describe "#children" do
      it "returns array of child nodes" do
        children = root.children
        expect(children).to be_an(Array)
        expect(children).to all(be_a(backend::Node))
      end
    end

    describe "#child_count" do
      it "returns number of children" do
        expect(root.child_count).to be_a(Integer)
        expect(root.child_count).to be >= 0
      end
    end

    describe "#start_line" do
      it "returns 1-based line number" do
        expect(root.start_line).to be_a(Integer)
        expect(root.start_line).to be >= 1
      end
    end

    describe "#end_line" do
      it "returns 1-based line number" do
        expect(root.end_line).to be_a(Integer)
        expect(root.end_line).to be >= 1
      end
    end
  end

  describe "BackendRegistry integration", :markly_backend do
    it "registers availability checker with TreeHaver::BackendRegistry" do
      expect(TreeHaver::BackendRegistry.available?(:markly)).to eq(backend.available?)
    end
  end
end

