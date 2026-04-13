# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe Markly::Merge::SmartMerger, "comment behavior matrix", :markly_backend do
  extend Ast::Merge::RSpec::CommentBehaviorMatrixAdapters

  it_behaves_like "Ast::Merge::CommentBehaviorMatrix" do
    markdown_link_definition_comment_matrix_adapter(
      analysis_class: Markly::Merge::FileAnalysis,
      merger_class: Markly::Merge::SmartMerger,
    )
  end
end
