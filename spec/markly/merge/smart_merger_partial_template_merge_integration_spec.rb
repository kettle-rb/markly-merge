# frozen_string_literal: true

require "spec_helper"
require "digest"

RSpec.describe Markly::Merge::SmartMerger, :integration do
  describe "Partial Template Merge Integration" do
    # Helper to extract text content from a markdown node
    def extract_node_text(node)
      raw = Ast::Merge::NodeTyping.unwrap(node)
      if raw.respond_to?(:to_plaintext)
        raw.to_plaintext.strip
      elsif raw.respond_to?(:string_content)
        raw.string_content.to_s.strip
      else
        ""
      end
    end

    # Helper to check if a node is the gem family H3 heading
    def gem_family_heading?(node)
      canonical_type = Ast::Merge::NodeTyping.merge_type_for(node) ||
        (node.respond_to?(:type) ? node.type : nil)

      return false unless canonical_type.to_s == "heading"

      raw = Ast::Merge::NodeTyping.unwrap(node)
      level = raw.respond_to?(:header_level) ? raw.header_level : nil
      return false unless level == 3

      text = extract_node_text(node)
      text.include?("*-merge") && text.include?("Gem Family")
    end

    # Gem family heading text used for signature matching
    let(:gem_family_heading) { "The `*-merge` Gem Family" }

    # Custom signature generator that identifies gem family section content.
    # Gives matching signatures to section content so template and destination
    # tables match even with different content.
    let(:section_aware_signature_generator) do
      lambda do |node|
        text = extract_node_text(node)

        # Check if this is the gem family H3 heading
        if gem_family_heading?(node)
          return [:gem_family_section, :heading, text[0, 30]]
        end

        canonical_type = Ast::Merge::NodeTyping.merge_type_for(node) ||
          (node.respond_to?(:type) ? node.type : nil)

        # Check if this is a paragraph about the gem family (intro text)
        if canonical_type.to_s == "paragraph"
          if text.include?("*-merge") && text.include?("gem family")
            return [:gem_family_section, :paragraph, :intro]
          end
        end

        # Check if this is one of the gem family tables
        if canonical_type.to_s == "table"
          if text.include?("tree_haver") || text.include?("ast-merge") ||
              text.include?("prism-merge") || text.include?("kettle-dev")
            # Use a Fixed signature so tables with different content but same purpose match
            return [:gem_family_section, :table, :gem_family_table]
          end
        end

        # Fall through to default signature (node itself)
        node
      end
    end

    describe "with add_template_only_nodes: false" do
      context "when destination HAS the gem family section" do
        let(:fixture_dir) { File.join(__dir__, "../../fixtures/reproducible/04_partial_template_merge_with_section") }
        let(:template) { File.read(File.join(fixture_dir, "template.md")) }
        let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }
        let(:expected_result) { File.read(File.join(fixture_dir, "result.md")) }

        it "updates the gem family section with template content" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: false,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # The gem family section should be updated
          expect(result.content).to include("Foundation: Cross-Ruby adapter")
          expect(result.content).to include("Infrastructure: Shared base classes")
          expect(result.content).to include("prism-merge")

          # The old content should be replaced
          expect(result.content).not_to include("OLD: Cross-Ruby adapter")
          expect(result.content).not_to include("OLD: Shared base classes")

          # The rest of the document should be preserved
          expect(result.content).to include("# My Awesome Gem")
          expect(result.content).to include("## Installation")
          expect(result.content).to include("## Usage")
          expect(result.content).to include("## Contributing")
          expect(result.content).to include("## License")
        end

        it "preserves the document structure outside the gem family section" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: false,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # Count sections - should have same structure
          expect(result.content.scan(/^## /).count).to eq(destination.scan(/^## /).count)
          expect(result.content.scan(/^### /).count).to eq(destination.scan(/^### /).count)
        end
      end

      context "when destination does NOT have the gem family section" do
        let(:fixture_dir) { File.join(__dir__, "../../fixtures/reproducible/05_partial_template_merge_without_section") }
        let(:template) { File.read(File.join(fixture_dir, "template.md")) }
        let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }
        let(:expected_result) { File.read(File.join(fixture_dir, "result.md")) }

        it "does NOT add the gem family section to the destination" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: false,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # The gem family section should NOT be added
          expect(result.content).not_to include(gem_family_heading)
          expect(result.content).not_to include("tree_haver")
          expect(result.content).not_to include("ast-merge")
          expect(result.content).not_to include("prism-merge")
        end

        it "preserves the destination content unchanged" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: false,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # The document should remain essentially unchanged
          expect(result.content).to include("# Different Gem")
          expect(result.content).to include("This is a completely different gem")
          expect(result.content).to include("## Installation")
          expect(result.content).to include("## Usage")
          expect(result.content).to include("## Features")
          expect(result.content).to include("- Feature one")
          expect(result.content).to include("- Feature two")
          expect(result.content).to include("- Feature three")
          expect(result.content).to include("## Contributing")
          expect(result.content).to include("## License")
        end

        it "does not change the destination when it has no matching section" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: false,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # This is the key regression test: content should be identical
          # (allowing for minor whitespace normalization by the parser)
          # Normalize both through Markly for fair comparison
          result_normalized = Markly.parse(result.content).to_commonmark
          expected_normalized = Markly.parse(expected_result).to_commonmark
          expect(result_normalized).to eq(expected_normalized)
        end
      end

      context "with preference: :destination" do
        context "when destination does NOT have the gem family section" do
          let(:fixture_dir) { File.join(__dir__, "../../fixtures/reproducible/05_partial_template_merge_without_section") }
          let(:template) { File.read(File.join(fixture_dir, "template.md")) }
          let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }

          it "does NOT add the gem family section regardless of preference" do
            merger = described_class.new(
              template,
              destination,
              preference: :destination,
              add_template_only_nodes: false,
              signature_generator: section_aware_signature_generator,
            )

            result = merger.merge_result

            # The gem family section should NOT be added
            expect(result.content).not_to include(gem_family_heading)
          end

          it "keeps destination content completely unchanged" do
            merger = described_class.new(
              template,
              destination,
              preference: :destination,
              add_template_only_nodes: false,
              signature_generator: section_aware_signature_generator,
            )

            result = merger.merge_result

            # With preference: :destination and no matching sections,
            # the output should be identical to the input destination
            # (allowing for parser normalization)
            # Normalize both through Markly for fair comparison
            result_normalized = Markly.parse(result.content).to_commonmark
            destination_normalized = Markly.parse(destination).to_commonmark
            expect(result_normalized).to eq(destination_normalized)
          end
        end
      end
    end

    describe "with add_template_only_nodes: true (for comparison)" do
      context "when destination does NOT have the gem family section" do
        let(:fixture_dir) { File.join(__dir__, "../../fixtures/reproducible/05_partial_template_merge_without_section") }
        let(:template) { File.read(File.join(fixture_dir, "template.md")) }
        let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }

        it "DOES add the gem family section when add_template_only_nodes is true" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: true,
            signature_generator: section_aware_signature_generator,
          )

          result = merger.merge_result

          # With add_template_only_nodes: true, the section SHOULD be added
          expect(result.content).to include(gem_family_heading)
          expect(result.content).to include("tree_haver")
        end
      end
    end
  end
end
