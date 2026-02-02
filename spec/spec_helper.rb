# frozen_string_literal: true

# Much of the config is loaded automatically by the .rspec config via spec_thin_helper
# This file is for gem-specific requires that individual specs may need
begin
  require "prism/merge"
rescue LoadError
  # Some specs will be skipped if prism-merge gem is not available
end
