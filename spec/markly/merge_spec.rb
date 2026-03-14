# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markly::Merge do
  it "has a version number" do
    expect(Markly::Merge::VERSION).not_to be_nil
  end

  it "autoloads PartialTemplateMerger" do
    expect(Markly::Merge::PartialTemplateMerger).to be_a(Class)
  end
end
