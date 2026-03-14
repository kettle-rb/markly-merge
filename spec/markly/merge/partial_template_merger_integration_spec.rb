# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markly::Merge::PartialTemplateMerger, :markly do
  describe "standalone HTML comment fixture parity" do
    let(:fixture_dir) { File.join(__dir__, "../../fixtures/reproducible/07_partial_replace_comments") }
    let(:template) { File.read(File.join(fixture_dir, "template.md")) }
    let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }
    let(:expected_result) { File.read(File.join(fixture_dir, "result.md")) }

    it "preserves a between-block standalone HTML comment during replace_mode section replacement" do
      result = described_class.new(
        template: template,
        destination: destination,
        anchor: {type: :heading, text: /Description/},
        preference: :template,
        replace_mode: true,
      ).merge

      expect(result.content).to eq(expected_result)
    end
  end

  it "preserves destination-only link reference definitions during replace_mode section replacement" do
    template = <<~MARKDOWN
      ## Description

      Template intro.

      Template body with [Docs][docs].
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      ## Description

      <!-- Destination docs -->

      [docs]: https://example.test/docs

      Destination body.

      ## After

      Keep me.
    MARKDOWN

    expected = <<~MARKDOWN
      # Title

      ## Description

      <!-- Destination docs -->

      [docs]: https://example.test/docs

      Template intro.

      Template body with [Docs][docs].

      ## After

      Keep me.
    MARKDOWN

    result = described_class.new(
      template: template,
      destination: destination,
      anchor: {type: :heading, text: /Description/},
      preference: :template,
      replace_mode: true,
    ).merge

    expect(result.content).to eq(expected)
    expect(result.stats).to include(
      mode: :replace,
      preserved_destination_comment_fragments: 1,
      preserved_destination_link_definitions: 1,
    )
  end
end
